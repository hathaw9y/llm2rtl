import random
import struct
import sys
import unittest
from fractions import Fraction
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts'))
import exact_numeric as n

class NumericTests(unittest.TestCase):
    def test_ties_and_subnormals(self):
        self.assertEqual(n.bf16(1+Fraction(1,256)), 0x3f80)
        self.assertEqual(n.bf16(1+Fraction(3,256)), 0x3f82)
        for bits, encode in ((149,n.f32),(133,n.bf16)):
            self.assertEqual(encode(Fraction(1,2**bits)),1)
            self.assertEqual(encode(Fraction(1,2**(bits+1))),0)
            self.assertEqual(encode(Fraction(3,2**(bits+1))),2)
        self.assertEqual(n.f32(16777217),n.f32(16777216))
        self.assertEqual(n.f32(16777219),n.f32(16777220))

    def test_signed_zeros(self):
        self.assertEqual(n.mul32(0x80000000,n.f32(1)),0x80000000)
        self.assertEqual(n.add32(0x80000000,0x80000000),0x80000000)
        self.assertEqual(n.add32(0x80000000,0),0)
        self.assertEqual(n.mul16(0x8000,n.bf16(1)),0x8000)

    def test_quantization_ties_saturation_and_zero_block(self):
        for value, expected in ((.5,0),(1.5,2),(2.5,2),(-.5,0),(-1.5,-2),(-2.5,-2),(200,127),(-200,-127)):
            self.assertEqual(n.quantize(n.bf16(value),n.f32(1)),expected)
        self.assertEqual(n.quantize(n.bf16(-1),n.f32(1),True),0)
        self.assertEqual(n.quantize(n.bf16(1),1),127)
        self.assertEqual(n.quantize(n.bf16(-1),1),-127)
        self.assertEqual(n.dynamic_scale([0,0x8000]),n.f32(1))

    def test_invalid_input_and_scale(self):
        for scale in (0,0x80000000,n.f32(-1),0x7f800000,0x7fc00000):
            with self.assertRaises(n.NumericError): n.quantize(n.bf16(1),scale)
        with self.assertRaises(n.NumericError): n.quantize(0x7f80,n.f32(1))
        with self.assertRaises(n.NumericError): n.dequantize(-128,n.f32(1))

    def test_scale_sequence_and_legal_maximum(self):
        dot=1536*127*127
        self.assertEqual(dot,24774144)
        self.assertEqual(n.scaled_output(dot,n.f32(Fraction(1,128)),n.f32(Fraction(1,128))),n.bf16(Fraction(dot,16384)))
        self.assertEqual(n.scaled_output(64,n.f32(1),n.f32(1),True),n.bf16(8))

    def test_independent_numpy_binary32_random(self):
        try: import numpy as np
        except ImportError: self.skipTest('independent NumPy oracle unavailable')
        rng=random.Random(20261008)
        def scalar(bits): return np.frombuffer(struct.pack('<I',bits),dtype='<f4')[0]
        def bits(value): return struct.unpack('<I',np.float32(value).tobytes())[0]
        with np.errstate(all='ignore'):
            for _ in range(3000):
                a,b=rng.getrandbits(32),rng.getrandbits(32)
                if not n.finite32(a) or not n.finite32(b): continue
                self.assertEqual(n.mul32(a,b),bits(scalar(a)*scalar(b)))
                self.assertEqual(n.add32(a,b),bits(scalar(a)+scalar(b)))
                if n.value32(b): self.assertEqual(n.div32(a,b),bits(scalar(a)/scalar(b)))

if __name__=='__main__': unittest.main()
