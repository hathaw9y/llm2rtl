"""Program-only Attention ISA v1; intentionally distinct from quantizer RTL ISA.
All execution consumes decoded command words and native bank byte payloads.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

LEGACY = Path(__file__).resolve().parents[1] / 'attention_int4_noscale_zcu104_r1'
sys.path.insert(0, str(LEGACY / 'python'))
import attention_reference as ref

OPS = dict(END=0, MM2S=1, S2MM=2, QUANTIZE=3, PROJECT=4, QK=5, SOFTMAX=6, PV=7)
NAMES = {v: k for k, v in OPS.items()}
FIELDS = dict(opcode=(120, 8), dst=(112, 8), src0=(104, 8), src1=(96, 8), descriptor=(64, 32), immediate=(0, 64))

def encode(name, dst=0, src0=0, src1=0, descriptor=0, immediate=0):
    fields = dict(opcode=OPS[name], dst=dst, src0=src0, src1=src1, descriptor=descriptor, immediate=immediate)
    word = 0
    for k, (shift, width) in FIELDS.items():
        if not isinstance(fields[k], int) or not 0 <= fields[k] < 1 << width:
            raise ValueError('instruction field overflow: ' + k)
        word |= fields[k] << shift
    return word

def decode(word):
    if not isinstance(word, int) or not 0 <= word < 1 << 128:
        raise ValueError('invalid 128-bit instruction')
    fields = {k: (word >> s) & ((1 << w)-1) for k, (s, w) in FIELDS.items()}
    if fields['opcode'] not in NAMES:
        raise ValueError('unknown opcode')
    return fields

def aligned(n):
    return (n + 15) // 16 * 16

def descriptor(shape, fmt):
    if not shape or any(not isinstance(x, int) or x < 1 for x in shape):
        raise ValueError('positive tensor dimensions required')
    ranks = {'f32': (2,3), 'bf16': (3,), 'u8': (1,), 'i4row': (2,3),
             'i4head': (3,), 'i4group32': (2,)}
    if fmt not in ranks or len(shape) not in ranks[fmt]:
        raise ValueError('tensor format/rank mismatch')
    n = int(np.prod(shape))
    scale_shape = None
    if fmt == 'i4row':
        scale_shape = [shape[0]]
    elif fmt == 'i4head':
        scale_shape = shape[:-1]
    elif fmt == 'i4group32':
        scale_shape = [shape[0], (shape[1]+31)//32]
    data_bytes = (n+1)//2 if fmt.startswith('i4') else n * {'f32': 4, 'bf16': 2, 'u8': 1}[fmt]
    scale_offset = aligned(data_bytes)
    total = scale_offset + (int(np.prod(scale_shape))*2 if scale_shape else 0)
    return dict(shape=list(shape), format=fmt, data_bytes=data_bytes, scale_shape=scale_shape,
                scale_offset=scale_offset, capacity_bytes=aligned(total))

def pack(desc, data, scales=None):
    a = np.asarray(data).reshape(desc['shape'])
    fmt = desc['format']
    if fmt.startswith('i4'):
        if np.any(a < -7) or np.any(a > 7) or np.any(a != np.floor(a)):
            raise ValueError('symmetric INT4 range')
        a = (a.astype(np.int32).ravel() & 15).astype(np.uint8)
        if len(a) % 2:
            a = np.append(a, np.uint8(0))
        raw = (a[0::2] | (a[1::2] << 4)).tobytes()
    else:
        raw = a.astype({'f32': '<f4', 'bf16': '<u2', 'u8': 'u1'}[fmt]).tobytes()
    out = bytearray(desc['capacity_bytes'])
    out[:len(raw)] = raw
    if desc['scale_shape']:
        s = np.asarray(scales, dtype='<u2').reshape(desc['scale_shape']).tobytes()
        off = desc['scale_offset']
        out[off:off+len(s)] = s
    return bytes(out)

def unpack(desc, raw):
    if len(raw) != desc['capacity_bytes']:
        raise ValueError('bank capacity mismatch')
    fmt, n = desc['format'], int(np.prod(desc['shape']))
    if fmt.startswith('i4'):
        b = np.frombuffer(raw[:desc['data_bytes']], dtype=np.uint8)
        a = np.stack((b & 15, b >> 4), axis=1).ravel()[:n].astype(np.int32)
        a = np.where(a >= 8, a-16, a)
        if np.any(a == -8):
            raise ValueError('reserved INT4 -8')
    else:
        a = np.frombuffer(raw[:desc['data_bytes']], dtype={'f32': '<f4', 'bf16': '<u2', 'u8': 'u1'}[fmt]).copy()
    scales = None
    if desc['scale_shape']:
        off = desc['scale_offset']
        scales = np.frombuffer(raw, dtype='<u2', count=int(np.prod(desc['scale_shape'])), offset=off).copy().reshape(desc['scale_shape'])
        decoded = scales.astype(np.uint32) << 16
        if np.any(scales < 0x0080) or np.any(decoded & 0x80000000) or np.any((decoded & 0x7f800000) == 0x7f800000):
            raise ValueError('nonpositive/nonfinite scale')
    return a.reshape(desc['shape']), scales

def compile_program(tokens=3, inputs=33, heads=2, head_dim=16, outputs=33, causal=True, query_indices=None):
    dims = (tokens, inputs, heads, head_dim, outputs)
    if any(not isinstance(x, int) or x < 1 for x in dims):
        raise ValueError('positive integer dimensions required')
    width = heads*head_dim
    queries = list(range(tokens)) if query_indices is None else list(query_indices)
    if not queries or any(not isinstance(q, int) or not 0 <= q < tokens for q in queries):
        raise ValueError('invalid query indices')
    # INT32 safety, not a claim of currently synthesized memory capacity.
    if head_dim*49 >= 1 << 31:
        raise ValueError('INT32 QK overflow bound')
    nq = len(queries)
    tensors = [('x', [tokens, inputs], 'f32'), ('wq', [width, inputs], 'i4group32'),
        ('wk', [width, inputs], 'i4group32'), ('wv', [width, inputs], 'i4group32'),
        ('wo', [outputs, width], 'i4group32'), ('mask', [tokens], 'u8'),
        ('x4', [tokens, inputs], 'i4row'), ('qfp', [tokens, width], 'f32'),
        ('kfp', [tokens, width], 'f32'), ('vfp', [tokens, width], 'f32'),
        ('q', [tokens, heads, head_dim], 'i4row'), ('k', [tokens, heads, head_dim], 'i4head'),
        ('v', [tokens, heads, head_dim], 'i4head'), ('scores', [nq, heads, tokens], 'f32'),
        ('probabilities', [nq, heads, tokens], 'bf16'), ('context', [nq, width], 'f32'),
        ('context4', [nq, width], 'i4row'), ('output_fp', [nq, outputs], 'f32'),
        ('output4', [nq, outputs], 'i4row')]
    banks = {name: i for i, (name, _, _) in enumerate(tensors)}
    descs = [dict(name=name, bank=i, **descriptor(shape, fmt)) for i, (name, shape, fmt) in enumerate(tensors)]
    cfg = dict(profile='attention_tensor_isa_v1', banks=descs, heads=heads, head_dim=head_dim,
               causal=bool(causal), query_indices=queries, group_size=32)
    words, transfers = [], {}
    cursor = 0x10000000
    for name in ('x', 'wq', 'wk', 'wv', 'wo', 'mask'):
        bank = banks[name]
        transfers[name] = cursor
        words.append(encode('MM2S', dst=bank, descriptor=bank, immediate=cursor))
        cursor += descs[bank]['capacity_bytes']
    def compute(op, dst, a, b=None):
        words.append(encode(op, dst=banks[dst], src0=banks[a], src1=0 if b is None else banks[b], descriptor=banks[dst]))
    compute('QUANTIZE', 'x4', 'x')
    for suffix in ('q', 'k', 'v'):
        compute('PROJECT', suffix+'fp', 'x4', 'w'+suffix)
        compute('QUANTIZE', suffix, suffix+'fp')
    compute('QK', 'scores', 'q', 'k')
    compute('SOFTMAX', 'probabilities', 'scores', 'mask')
    compute('PV', 'context', 'probabilities', 'v')
    compute('QUANTIZE', 'context4', 'context')
    compute('PROJECT', 'output_fp', 'context4', 'wo')
    compute('QUANTIZE', 'output4', 'output_fp')
    transfers['output4'] = cursor
    words.append(encode('S2MM', src0=banks['output4'], descriptor=banks['output4'], immediate=cursor))
    words.append(encode('END'))
    cfg['ddr_addresses'] = transfers
    return cfg, words

class Interpreter:
    def __init__(self, config, ddr):
        self.cfg, self.ddr = config, dict(ddr)
        self.banks, self.trace = {}, []
        self.descs = config['banks']
        if len(self.descs) != 19:
            raise ValueError('this profile requires 19 tensor banks')
        for i, d in enumerate(self.descs):
            if d != dict(name=d['name'], bank=i, **descriptor(d['shape'], d['format'])):
                raise ValueError('invalid tensor descriptor')
        if config['profile'] != 'attention_tensor_isa_v1' or config['group_size'] != 32:
            raise ValueError('unsupported profile')
        expected, _ = compile_program(self.descs[0]['shape'][0], self.descs[0]['shape'][1],
            config['heads'], config['head_dim'], self.descs[-1]['shape'][-1],
            config['causal'], config['query_indices'])
        if expected['banks'] != self.descs:
            raise ValueError('tensor descriptors inconsistent with program context')
    def read(self, bank):
        if bank not in self.banks:
            raise ValueError('uninitialized bank')
        return unpack(self.descs[bank], self.banks[bank])
    def run(self, words):
        ended = False
        for pc, word in enumerate(words):
            f = decode(word)
            op = NAMES[f.pop('opcode')]
            dst, a, b, di, imm = (f[x] for x in ('dst','src0','src1','descriptor','immediate'))
            if ended:
                raise ValueError('instruction after END')
            if op == 'END':
                if any(f.values()):
                    raise ValueError('nonzero END fields')
                ended = True
            else:
                if any(i >= len(self.descs) for i in (dst,a,b,di)):
                    raise ValueError('invalid bank/descriptor')
                target = a if op == 'S2MM' else dst
                if di != target:
                    raise ValueError('descriptor does not identify operand')
                d = self.descs[target]
                if op in ('MM2S','S2MM'):
                    if imm % 16 or b or (a if op == 'MM2S' else dst):
                        raise ValueError('DMA alignment/reserved fields')
                    if op == 'MM2S':
                        payload = self.ddr.get(imm)
                        if payload is None or len(payload) != d['capacity_bytes']:
                            raise ValueError('DMA source extent mismatch')
                        unpack(d, payload)
                        self.banks[dst] = payload
                    else:
                        self.read(a)
                        self.ddr[imm] = self.banks[a]
                else:
                    if imm or dst in (a,b) or (op == 'QUANTIZE' and b):
                        raise ValueError('compute alias/reserved fields')
                    x, xs = self.read(a)
                    y, ys = self.read(b) if op != 'QUANTIZE' else (None,None)
                    af, bf, df = self.descs[a]['format'], self.descs[b]['format'], d['format']
                    scales = None
                    if op == 'QUANTIZE':
                        if af != 'f32' or df not in ('i4row','i4head') or x.size != int(np.prod(d['shape'])):
                            raise ValueError('quantize layout')
                        rows = x.reshape(d['shape'][0], -1) if df == 'i4row' else x.reshape(-1, d['shape'][-1])
                        result, scales = ref.quantize(rows)
                    elif op == 'PROJECT':
                        if (af,bf,df) != ('i4row','i4group32','f32') or x.ndim != 2 or y.ndim != 2 or d['shape'] != [len(x),len(y)]:
                            raise ValueError('projection layout')
                        result = ref.project(x,xs,y,ys)
                    elif op == 'QK':
                        h, hd = self.cfg['heads'], self.cfg['head_dim']
                        if (af,bf,df) != ('i4row','i4head','f32') or x.shape != y.shape or x.shape[1:] != (h,hd) or d['shape'] != [len(self.cfg['query_indices']),h,len(y)]:
                            raise ValueError('QK layout')
                        result = np.zeros(d['shape'], np.float32)
                        factor = np.float32(1/np.sqrt(np.float64(hd)))
                        for row, q in enumerate(self.cfg['query_indices']):
                            for head in range(h):
                                for key in range(len(y)):
                                    dot = sum(int(u)*int(v) for u,v in zip(x[q,head],y[key,head]))
                                    scale = np.float32(ref.bf16_value(xs[q])*ref.bf16_value(ys[key,head]))
                                    result[row,head,key] = np.float32(np.float32(np.float32(dot)*scale)*factor)
                    elif op == 'SOFTMAX':
                        if (af,bf,df) != ('f32','u8','bf16') or list(x.shape) != d['shape'] or y.shape != (x.shape[-1],) or np.any(y > 1):
                            raise ValueError('softmax layout/mask')
                        result = np.zeros(d['shape'], np.uint16)
                        for row,q in enumerate(self.cfg['query_indices']):
                            allowed = y.astype(bool) & ((np.arange(len(y)) <= q) if self.cfg['causal'] else True)
                            keys = np.flatnonzero(allowed)
                            for head in range(self.cfg['heads']):
                                if not len(keys):
                                    continue
                                maximum = max(x[row,head,key] for key in keys)
                                exp, total = {}, np.float32(0)
                                for key in keys:
                                    exp[key] = np.float32(np.exp(np.float32(x[row,head,key]-maximum)))
                                    total = np.float32(total+exp[key])
                                for key in keys:
                                    result[row,head,key] = ref.bf16_round(np.float32(exp[key]/total))
                    elif op == 'PV':
                        h, hd = self.cfg['heads'], self.cfg['head_dim']
                        if (af,bf,df) != ('bf16','i4head','f32') or x.shape != (len(self.cfg['query_indices']),h,len(y)) or y.shape[1:] != (h,hd) or d['shape'] != [len(x),h*hd]:
                            raise ValueError('PV layout')
                        result = np.zeros(d['shape'], np.float32)
                        for row in range(len(x)):
                            for head in range(h):
                                for lane in range(hd):
                                    total = np.float32(0)
                                    for key in range(len(y)):
                                        # Masked probabilities are zero; skip to match zero-state reference.
                                        if x[row,head,key] == 0:
                                            continue
                                        v = np.float32(np.float32(y[key,head,lane])*ref.bf16_value(ys[key,head]))
                                        total = np.float32(total+np.float32(ref.bf16_value(x[row,head,key])*v))
                                    result[row,head*hd+lane] = total
                    else:
                        raise ValueError('unsupported compute')
                    self.banks[dst] = pack(d,result,scales)
            self.trace.append(dict(pc=pc, opcode=op, **f))
        if not ended:
            raise ValueError('missing END')
        return self.ddr

def prepare(config, x, wq, wk, wv, wo, mask):
    tensors = {'x': (x,None), 'mask': (mask,None)}
    for name, w in zip(('wq','wk','wv','wo'), (wq,wk,wv,wo)):
        tensors[name] = ref.quantize_weights(w)  # Offline static weight export only.
    return {config['ddr_addresses'][d['name']]: pack(d,*tensors[d['name']])
            for d in config['banks'] if d['name'] in tensors}

def generate(directory, tokens=3, inputs=33, heads=2, head_dim=16, outputs=33, causal=True, query_indices=None):
    cfg, words = compile_program(tokens,inputs,heads,head_dim,outputs,causal,query_indices)
    rng = np.random.RandomState(41)
    x = rng.normal(size=(tokens,inputs)).astype(np.float32)
    weights = [rng.normal(size=(heads*head_dim,inputs)).astype(np.float32) for _ in range(3)]
    wo = rng.normal(size=(outputs,heads*head_dim)).astype(np.float32)
    mask = np.ones(tokens,np.uint8)
    ddr = prepare(cfg,x,*weights,wo,mask)
    machine = Interpreter(cfg,ddr)
    machine.run(words)
    expected = ref.attention(x,*weights,wo,heads,causal,mask.astype(bool),query_indices)
    for name,key in [('output4','output4'),('output_fp','output_fp'),('context4','context4'),('probabilities','probabilities_bf16'),('q','q4'),('k','k4'),('v','v4')]:
        data, scales = machine.read(next(d['bank'] for d in cfg['banks'] if d['name']==name))
        if not np.array_equal(data,expected[key]):
            raise AssertionError('ISA mismatch: '+name)
        scale_key = {'output4':'output_scale','context4':'context_scale','q':'q_scale','k':'k_scale','v':'v_scale'}.get(name)
        if scale_key and not np.array_equal(scales,expected[scale_key]):
            raise AssertionError('ISA scale mismatch: '+name)
    directory = Path(directory)
    directory.mkdir(parents=True,exist_ok=True)
    (directory/'program.mem').write_text(''.join(f'{word:032x}\n' for word in words))
    (directory/'program.bin').write_bytes(b''.join(word.to_bytes(16,'little') for word in words))
    (directory/'descriptor_table.json').write_text(json.dumps(cfg,indent=2)+'\n')
    (directory/'program_listing.json').write_text(json.dumps(machine.trace,indent=2)+'\n')
    assembly = []
    for item in machine.trace:
        op = item['opcode']
        desc = cfg['banks'][item['descriptor']]
        if op == 'END':
            operands = ''
        elif op in ('MM2S','S2MM'):
            operands = f"{desc['name']} DDR=0x{item['immediate']:08x} bytes={desc['capacity_bytes']}"
        else:
            names = [cfg['banks'][item[key]]['name'] for key in ('dst','src0')]
            if op != 'QUANTIZE':
                names.append(cfg['banks'][item['src1']]['name'])
            operands = ', '.join(names)
        assembly.append(f"{item['pc']:03d} {op:9s} {operands}")
    (directory/'program.asm').write_text('\n'.join(assembly)+'\n')
    for address, payload in ddr.items():
        (directory/f'ddr_{address:08x}.bin').write_bytes(payload)
    (directory/'expected_output.bin').write_bytes(machine.ddr[cfg['ddr_addresses']['output4']])
    np.savez(directory/'reference_inputs.npz',x=x,wq=weights[0],wk=weights[1],wv=weights[2],wo=wo,mask=mask)
    files = [Path(__file__), LEGACY/'python/attention_reference.py', LEGACY/'reference/quantizer_reference.py'] + sorted(p for p in directory.iterdir() if p.name != 'manifest.json')
    manifest = dict(status='ISA_INTERPRETER_REFERENCE_PASS', instructions=len(words), rtl_full_attention=False,
                    hashes={str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
    (directory/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

def replay(directory):
    directory = Path(directory)
    cfg = json.loads((directory/'descriptor_table.json').read_text())
    binary = (directory/'program.bin').read_bytes()
    if len(binary) % 16:
        raise ValueError('truncated instruction binary')
    words = [int.from_bytes(binary[i:i+16],'little') for i in range(0,len(binary),16)]
    ddr = {int(p.stem[4:],16):p.read_bytes() for p in directory.glob('ddr_*.bin')}
    machine = Interpreter(cfg,ddr)
    machine.run(words)
    if machine.ddr[cfg['ddr_addresses']['output4']] != (directory/'expected_output.bin').read_bytes():
        raise AssertionError('saved binary output mismatch')
    return len(machine.trace)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--out',type=Path)
    mode.add_argument('--replay',type=Path)
    for name,default in [('tokens',3),('inputs',33),('heads',2),('head-dim',16),('outputs',33)]:
        parser.add_argument('--'+name,type=int,default=default)
    parser.add_argument('--noncausal',action='store_true')
    parser.add_argument('--queries',type=int,nargs='+')
    args = parser.parse_args()
    if args.replay:
        print('SAVED_PROGRAM_PASS', 'instructions='+str(replay(args.replay)))
    else:
        result = generate(args.out,args.tokens,args.inputs,args.heads,args.head_dim,args.outputs,not args.noncausal,args.queries)
        print(result['status'], 'instructions='+str(result['instructions']))
