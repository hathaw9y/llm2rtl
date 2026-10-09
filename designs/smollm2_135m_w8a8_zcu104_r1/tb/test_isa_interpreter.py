import sys
import unittest
from fractions import Fraction
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from isa_interpreter import Interpreter, ExecutionError, pack16,pack32,unpack16,signed
from isa_codec import encode
import exact_numeric as n

class InterpreterTests(unittest.TestCase):
    def test_embedding_selected_lane(self):
        for lane in range(4):
            i=Interpreter(); i.ddr.map(0x1000,bytes([2])*576); i.ddr.map(0x2000,pack32([n.f32(x) for x in (1,2,3,4)]))
            i.step(i.config(3,'embedding_rows_INT8',1,576))
            for offset,count,address,aux in ((0,576,0x1000,0),(294912,16,0x2000,1|(lane<<1))):
                i.step(encode('DMA_LOAD',(3,0,0),local_byte_offset=offset,byte_count=count,ddr_address=address,aux=aux))
            i.step(encode('DEQUANTIZE',(3,0,0),m_count=1,k=576))
            self.assertEqual(unpack16(i.banks[0].bytes()),[n.bf16(2*(lane+1))]*576)

    def test_missing_scale_and_partial_coverage(self):
        i=Interpreter(); i.step(i.config(3,'weight_INT8',16,576))
        b=i.banks[3]; b.write(0,bytes(16*576)); self.assertFalse(b.ready())
        b.write(294912,pack32([n.f32(1)])+bytes(12)); self.assertTrue(b.ready())
        old=i.config(3,'weight_INT8',16,576); i.step(old)
        with self.assertRaises(ExecutionError): i.step(old)
        b.write(0,bytes(16)); b.write(0,bytes(16)); self.assertFalse(b.ready('data'))

    def test_B7_component_preservation_and_failure(self):
        i=Interpreter(); i.step(i.config(7,'RoPE_and_static_KV_scales',30,64,component=2))
        i.banks[7].write(4096,bytes(1920)); before=i.banks[7].bytes('static')
        i.step(i.config(7,'RoPE_and_static_KV_scales',1,64,component=1))
        with self.assertRaises(ExecutionError):
            i.step(encode('DMA_LOAD',(7,0,0),byte_count=128,ddr_address=0x1000))
        self.assertTrue(i.banks[7].ready('static')); self.assertFalse(i.banks[7].ready('rope'))
        self.assertEqual(i.banks[7].bytes('static'),before)

    def test_quantize_full_K_two_row_groups(self):
        i=Interpreter(); values=[n.bf16(1)]*(16*576)+[n.bf16(-2)]*576
        i.auto_output(2,'norm_output',17,576,pack16(values))
        i.step(encode('QUANTIZE',(2,0,13),mode=0,m_count=17,k=576))
        self.assertEqual(signed(i.banks[13].bytes()),[127]*(16*576)+[-127]*576)

    def test_GEMM_N_tiles_and_INT32_bound(self):
        i=Interpreter(); k=1536
        i.auto_output(13,'A_INT8',1,k,bytes([127])*k,[n.f32(Fraction(1,128))])
        i.step(i.config(1,'projection_output',1,576))
        for start,bank in ((0,3),(192,15),(384,3)):
            i.auto_output(bank,'weight_INT8',192,k,bytes([127])*(192*k),[n.f32(Fraction(1,128))]*12)
            i.step(encode('GEMM_INT8',(13,bank,1),n_start=start,n_total=576,m_count=1,k=k,n_tile=192))
            self.assertEqual(i.banks[1].ready(),start==384)
            i.run([0])
        expected=n.bf16(Fraction(24774144,16384))
        self.assertEqual(unpack16(i.banks[1].bytes()),[expected]*576)

    def test_QK_PV_GQA_scales_and_causal_mask(self):
        i=Interpreter(); length=33; rows=2; padded=48
        i.auto_output(14,'Q_INT8',rows,576,bytes([1])*(rows*576),[n.f32(h+1) for h in range(9)])
        kv=bytes(h+1 for t in range(length) for h in range(3) for _ in range(64))
        i.auto_output(8,'K_current_or_cache_INT8',length,192,kv,[n.f32(Fraction(1,2))]*3)
        f=dict(rows=rows,kv_len=length,query_start=31)
        i.step(encode('ATTN_SCORE_INT8',(14,8,10),**f))
        output=unpack16(i.banks[10].bytes())
        for r in range(rows):
            for h in range(9):
                base=(r*9+h)*padded
                expected=n.bf16(4*(h+1)*(h//3+1))
                self.assertEqual(output[base:base+32+r],[expected]*(32+r))
                self.assertTrue(all(v==0 for v in output[base+32+r:base+padded]))
        p=bytes(1 if t<=31+r and t<length else 0 for r in range(rows) for h in range(9) for t in range(padded))
        i.auto_output(13,'probability_INT8',rows,length,p,[n.f32(1)]*9,position=31)
        i.auto_output(9,'V_current_or_cache_INT8',length,192,kv,[n.f32(g+1) for h in range(3) for g in range(4)])
        i.step(encode('ATTN_VALUE_INT8',(13,9,11),**f))
        output=unpack16(i.banks[11].bytes())
        for r in range(rows):
            for h in range(9):
                for d in range(64):
                    self.assertEqual(output[r*576+h*64+d],n.bf16((32+r)*(h//3+1)*(d//16+1)))

    def test_P_quantization_ignores_mask_and_padding(self):
        i=Interpreter(); values=[n.bf16(1) if t<2 else n.bf16(100) for h in range(9) for t in range(16)]
        i.auto_output(10,'probability_BF16',1,3,pack16(values),position=1)
        i.step(encode('QUANTIZE',(10,0,13),mode=4,m_count=1,k=3,kv_len=3,query_start=1))
        self.assertEqual(signed(i.banks[13].bytes()),[v for h in range(9) for v in ([127,127]+[0]*14)])

    def test_negative_P_rejected_without_success(self):
        i=Interpreter(); i.auto_output(13,'probability_INT8',1,1,bytes([255])+bytes(143),[n.f32(1)]*9)
        i.auto_output(9,'V_current_or_cache_INT8',1,192,bytes(192),[n.f32(1)]*12)
        with self.assertRaises(ExecutionError): i.step(encode('ATTN_VALUE_INT8',(13,9,11),rows=1,kv_len=1))
        self.assertTrue(i.ledger[-1]['status'].startswith('ERROR'))
        self.assertFalse(any(b.busy for b in i.banks))

    def test_attention_context_1024_legal_maximum(self):
        i=Interpreter()
        i.auto_output(13,'probability_INT8',1,1024,bytes([127])*(9*1024),[n.f32(Fraction(1,128))]*9,position=1023)
        i.auto_output(9,'V_current_or_cache_INT8',1024,192,bytes([127])*(1024*192),[n.f32(Fraction(1,128))]*12)
        i.step(encode('ATTN_VALUE_INT8',(13,9,11),rows=1,kv_len=1024,query_start=1023))
        self.assertEqual(unpack16(i.banks[11].bytes()),[n.bf16(Fraction(16516096,16384))]*576)

    def test_last_source_row_and_single_N_tail(self):
        i=Interpreter()
        i.auto_output(13,'A_INT8',32,576,bytes(31*576)+bytes([3])*576,[n.f32(1),n.f32(2)])
        i.auto_output(15,'weight_INT8',1,576,bytes([2])*576,[n.f32(Fraction(1,4))])
        i.step(i.config(1,'projection_output',1,576))
        i.step(encode('GEMM_INT8',(13,15,1),n_start=0,n_total=576,m_start=31,m_count=1,k=576,n_tile=1))
        self.assertEqual(unpack16(i.banks[1].bytes())[0],n.bf16(1728))
        self.assertFalse(i.banks[1].ready())

    def test_reference_nonlinear_zero_and_RoPE_rotation(self):
        i=Interpreter()
        i.auto_output(0,'hidden',1,576,bytes(1152)); i.auto_output(3,'gamma_BF16',1,576,pack16([n.bf16(1)]*576))
        i.step(encode('RMSNORM',(0,3,2),rows=1))
        self.assertEqual(i.banks[2].bytes(),bytes(1152))
        i.auto_output(1,'projection_output',1,576,pack16([n.bf16(2)]*576))
        i.step(encode('ADD',(0,1,5),rows=1))
        self.assertEqual(unpack16(i.banks[5].bytes()),[n.bf16(2)]*576)
        i.auto_output(8,'gate_BF16',1,1536,bytes(3072)); i.auto_output(9,'up_BF16',1,1536,pack16([n.bf16(1)]*1536))
        i.step(encode('SILU_MUL',(8,9,10),rows=1))
        self.assertEqual(i.banks[10].bytes(),bytes(3072))
        i.auto_output(4,'Q_BF16',1,576,pack16(([n.bf16(2)]*32+[n.bf16(3)]*32)*9))
        i.step(i.config(7,'RoPE_and_static_KV_scales',1,64,component=1))
        i.banks[7].write(0,pack16([0]*32+[n.bf16(1)]*32))
        i.step(encode('ROPE',(4,7,0),rows=1))
        self.assertEqual(unpack16(i.banks[4].bytes()),([n.bf16(-3)]*32+[n.bf16(2)]*32)*9)

    def test_softmax_uniform_reference_and_padding(self):
        i=Interpreter(); i.auto_output(10,'score_BF16',1,3,bytes(9*16*2),position=2)
        i.step(encode('SOFTMAX',(10,0,0),rows=1,kv_len=3,query_start=2))
        self.assertEqual(unpack16(i.banks[10].bytes()),([n.bf16(Fraction(1,3))]*3+[0]*13)*9)

if __name__=='__main__': unittest.main()
