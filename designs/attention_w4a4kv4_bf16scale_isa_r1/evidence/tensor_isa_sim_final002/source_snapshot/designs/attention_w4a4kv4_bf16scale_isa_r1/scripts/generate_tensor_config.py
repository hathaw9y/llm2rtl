#!/usr/bin/env python3
"""Compile a bounded immutable tensor descriptor/context ROM; never changes programs."""
import argparse, hashlib, importlib.util, json, math, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
DESIGN = Path(__file__).resolve().parents[1]
FORMATS = {'f32':0,'bf16':1,'u8':2,'i4row':3,'i4head':4,'i4group32':5}

def legal(op, d, a, b):
    ds, aa, bb = d['shape'], a['shape'], b['shape']
    df, af, bf = d['format'], a['format'], b['format']
    if op == 3:
        return af == 'f32' and df in ('i4row','i4head') and math.prod(ds)==math.prod(aa) and ds[0]==aa[0] and (df!='i4head' or len(ds)==3) and len(aa)>=2 and len(ds)>=2
    if op == 4:
        return af=='i4row' and bf=='i4group32' and df=='f32' and len(aa)==len(bb)==len(ds)==2 and ds==[aa[0],bb[0]] and aa[1]==bb[1]
    if op == 5:
        return af=='i4row' and bf=='i4head' and df=='f32' and len(aa)==len(bb)==len(ds)==3 and aa==bb and ds[1:]==[aa[1],aa[0]]
    if op == 6:
        return af=='f32' and bf=='u8' and df=='bf16' and len(aa)==3 and ds==aa and bb==[aa[2]]
    if op == 7:
        return af=='bf16' and bf=='i4head' and df=='f32' and len(aa)==len(bb)==3 and len(ds)==2 and aa[1]==bb[1] and aa[2]==bb[0] and ds==[aa[0],bb[1]*bb[2]]
    return False

def generate(descriptor, output_dir):
    packet_path=DESIGN/'modules/attention_tensor_control.json'
    assert hashlib.sha256(packet_path.read_bytes()).hexdigest()=='53fe7ef380ce28536cd9c48be01b1957230f7263bbf5c65bc8eb872cc6a38ec2'
    packet=json.loads(packet_path.read_text())
    pins=dict(packet['common_contracts'])
    for key in ('rtl_contract','isa'):
        pins[packet[key]['path']]=packet[key]['sha256']
    for path, pin in pins.items():
        if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=pin: raise ValueError('identity mismatch: '+path)
    cfg=json.loads(Path(descriptor).read_text()); banks=cfg['banks']
    if len(banks)!=19 or cfg['group_size']!=32: raise ValueError('19-bank group32 profile required')
    tokens,inputs=banks[0]['shape']; outputs=banks[17]['shape'][1]
    heads,hd=cfg['heads'],cfg['head_dim']; queries=cfg['query_indices']
    if not (1<=tokens<=32 and 1<=inputs<=256 and 1<=outputs<=256 and 1<=heads<=4 and 1<=hd<=64 and heads*hd<=256 and 1<=len(queries)<=32): raise ValueError('outside bounded RTL profile')
    spec=importlib.util.spec_from_file_location('tensor_isa_program',DESIGN/'isa_program.py'); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    expected,_=mod.compile_program(tokens,inputs,heads,hd,outputs,cfg['causal'],queries)
    if cfg!=expected: raise ValueError('descriptor table differs from canonical immutable profile')
    packed=[]; depths=[]
    for bank in banks:
        shape=bank['shape']+[1]*(3-len(bank['shape']))
        header=(1<<31)|(FORMATS[bank['format']]<<28)|(len(bank['shape'])<<26)
        fields=[header,*shape,bank['data_bytes'],bank['scale_offset'],math.prod(bank['scale_shape']) if bank['scale_shape'] else 0,bank['capacity_bytes']]
        packed.append(''.join(f'{v:08x}' for v in fields))
        words=bank['capacity_bytes']//16
        depths.append(max(64,1<<(words-1).bit_length()))
    qk=struct.unpack('<I',struct.pack('<f',1/math.sqrt(hd)))[0]
    lines=['`timescale 1ns/1ps','// Generated immutable configuration; descriptor source SHA256 '+hashlib.sha256(Path(descriptor).read_bytes()).hexdigest(), 'package attention_tensor_config_pkg;', '  import attention_tensor_pkg::*;']
    for name,width,value in [('CTX_TOKENS',6,tokens),('CTX_HEADS',3,heads),('CTX_HEAD_DIM',7,hd),('CTX_QUERY_COUNT',6,len(queries)),('CTX_CAUSAL',1,int(cfg['causal']))]: lines.append(f'  localparam logic [{width-1}:0] {name} = {width}\'d{value};')
    lines+= [f"  localparam logic [31:0] CTX_QK_FACTOR = 32'h{qk:08x};", '  localparam int BANK_DEPTHS [0:18] = \'{'+','.join(map(str,depths))+'};', '  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);', "    case (bank)"]
    lines += [f"      5'd{i}: get_descriptor = 256'h{value};" for i,value in enumerate(packed)]
    lines+= ["      default: get_descriptor = '0;",'    endcase','  endfunction', '  function automatic logic [31:0] capacity_words(input logic [4:0] bank);','    tensor_desc_t unused_d;','    unused_d=get_descriptor(bank);','    return unused_d.capacity_bytes >> 4;','  endfunction','  function automatic logic [4:0] query_value(input logic [4:0] index);','    case(index)']
    lines += [f"      5'd{i}: query_value=5'd{q};" for i,q in enumerate(queries)]
    lines += ["      default: query_value='0;",'    endcase','  endfunction','  function automatic logic compute_legal(input logic [7:0] opcode, dst, src0, src1);','    case ({opcode,dst,src0,src1})']
    for op in range(3,8):
      for di,d in enumerate(banks):
       for ai,a in enumerate(banks):
        for bi,b in enumerate(banks):
         if di==ai or (op!=3 and (di==bi or ai==bi)) or (op==3 and bi!=0): continue
         if legal(op,d,a,b): lines.append(f"      32'h{op:02x}{di:02x}{ai:02x}{bi:02x}: compute_legal=1'b1;")
    lines+= ["      default: compute_legal=1'b0;",'    endcase','  endfunction','endpackage','']
    out=Path(output_dir); out.mkdir(parents=True,exist_ok=True); (out/'attention_tensor_config_pkg.sv').write_text('\n'.join(lines))
    return out/'attention_tensor_config_pkg.sv'

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--descriptor',type=Path,default=DESIGN/'rtl_vectors/prefill/descriptor_table.json'); parser.add_argument('--output-dir',type=Path,default=DESIGN/'rtl'); args=parser.parse_args(); print(generate(args.descriptor,args.output_dir))
