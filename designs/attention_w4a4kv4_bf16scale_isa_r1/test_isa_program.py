import copy
import tempfile
import unittest
from pathlib import Path
import numpy as np
import isa_program as isa

class AttentionProgramTests(unittest.TestCase):
    def run_case(self, tokens=3, inputs=33, heads=2, dim=3, outputs=5,
                 causal=True, queries=None, mask=None, zero=False):
        cfg, words = isa.compile_program(tokens,inputs,heads,dim,outputs,causal,queries)
        rng = np.random.RandomState(122)
        x = rng.uniform(-4,4,(tokens,inputs)).astype(np.float32)
        ws = [rng.normal(size=(heads*dim,inputs)).astype(np.float32) for _ in range(3)]
        wo = rng.normal(size=(outputs,heads*dim)).astype(np.float32)
        if zero:
            x.fill(0)
        mask = np.ones(tokens,np.uint8) if mask is None else np.asarray(mask,np.uint8)
        machine = isa.Interpreter(cfg,isa.prepare(cfg,x,*ws,wo,mask))
        machine.run(words)
        expected = isa.ref.attention(x,*ws,wo,heads,causal,mask.astype(bool),queries)
        names = dict(q=('q4','q_scale'),k=('k4','k_scale'),v=('v4','v_scale'),
                     probabilities=('probabilities_bf16',None),context4=('context4','context_scale'),
                     output_fp=('output_fp',None),output4=('output4','output_scale'))
        for name,(key,scale_key) in names.items():
            bank = next(d['bank'] for d in cfg['banks'] if d['name']==name)
            data,scales = machine.read(bank)
            # Compare exact stored bits, including signed FP32 zero.
            self.assertEqual(data.astype(expected[key].dtype).tobytes(),expected[key].tobytes(),name)
            if scale_key:
                self.assertEqual(scales.tobytes(),expected[scale_key].tobytes(),name+' scales')
        out = cfg['banks'][-1]
        self.assertEqual(machine.ddr[cfg['ddr_addresses']['output4']],machine.banks[out['bank']])
        self.assertEqual(len(machine.trace),len(words))
        return cfg,words,machine

    def test_prefill_group32_tail(self):
        self.run_case(inputs=33,heads=3,dim=11,outputs=35)

    def test_noncausal_padding_and_query_order(self):
        self.run_case(tokens=4,causal=False,queries=[3,0,3],mask=[1,0,1,0])

    def test_causal_query_selection(self):
        self.run_case(tokens=4,queries=[3],mask=[0,1,1,1])

    def test_all_masked_and_zero_logits(self):
        self.run_case(mask=[0,0,0])
        self.run_case(zero=True)

    def test_row_longer_than_existing_quantizer(self):
        # Proposed multirow kernel semantics; no claim current MAX256 RTL executes it.
        self.run_case(tokens=1,inputs=257,heads=1,dim=3,outputs=2)

    def test_program_artifacts_roundtrip(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = isa.generate(tmp,tokens=2,inputs=5,heads=1,head_dim=3,outputs=4)
            self.assertEqual(report['status'],'ISA_INTERPRETER_REFERENCE_PASS')
            binary = (Path(tmp)/'program.bin').read_bytes()
            words = [int.from_bytes(binary[i:i+16],'little') for i in range(0,len(binary),16)]
            self.assertEqual(words,[int(x,16) for x in (Path(tmp)/'program.mem').read_text().splitlines()])
            import json
            cfg = json.loads((Path(tmp)/'descriptor_table.json').read_text())
            ddr = {int(p.stem[4:],16):p.read_bytes() for p in Path(tmp).glob('ddr_*.bin')}
            machine = isa.Interpreter(cfg,ddr)
            machine.run(words)
            self.assertEqual(machine.ddr[cfg['ddr_addresses']['output4']],(Path(tmp)/'expected_output.bin').read_bytes())

    def test_invalid_instruction_and_lifecycle(self):
        cfg,words,machine = self.run_case(inputs=3,heads=1,dim=2,outputs=2)
        ddr = {addr:raw for addr,raw in machine.ddr.items() if addr!=cfg['ddr_addresses']['output4']}
        cases = [words[:-1],words+[isa.encode('END')], [isa.encode('END',dst=1)],
                 [255 << 120], [isa.encode('PROJECT',dst=7,src0=6,src1=1,descriptor=7),isa.encode('END')],
                 [isa.encode('MM2S',dst=255,descriptor=255),isa.encode('END')],
                 [isa.encode('MM2S',dst=0,descriptor=0,immediate=3),isa.encode('END')],
                 words[:6]+[isa.encode('QUANTIZE',dst=0,src0=0),isa.encode('END')],
                 words[:6]+[isa.encode('QUANTIZE',dst=6,src0=0,descriptor=7),isa.encode('END')]]
        for sequence in cases:
            with self.subTest(sequence=sequence),self.assertRaises(ValueError):
                isa.Interpreter(cfg,ddr).run(sequence)
        with self.assertRaises(ValueError):
            isa.encode('QK',dst=256)
        with self.assertRaises(ValueError):
            isa.decode(1 << 128)

    def test_descriptor_capacity_scale_and_shape_errors(self):
        cfg,words = isa.compile_program(tokens=1,inputs=3,heads=1,head_dim=2,outputs=2)
        bad = copy.deepcopy(cfg)
        bad['banks'][0]['capacity_bytes'] += 16
        with self.assertRaises(ValueError):
            isa.Interpreter(bad,{})
        with self.assertRaises(ValueError):
            isa.Interpreter(cfg,{cfg['ddr_addresses']['x']:b''}).run(words)
        desc = isa.descriptor([1,3],'i4row')
        for scale in (0,1,0xbf80,0x7f80,0x7fc0):
            with self.assertRaises(ValueError):
                isa.unpack(desc,isa.pack(desc,[[1,2,3]],[scale]))
        bad = copy.deepcopy(cfg)
        bad['query_indices'] = [-1]
        with self.assertRaises(ValueError):
            isa.Interpreter(bad,{})
        with self.assertRaises(ValueError):
            isa.descriptor([-1,3],'f32')
        with self.assertRaises(ValueError):
            isa.compile_program(query_indices=[-1])
        with self.assertRaises(ValueError):
            isa.compile_program(tokens=0)

if __name__ == '__main__':
    unittest.main()
