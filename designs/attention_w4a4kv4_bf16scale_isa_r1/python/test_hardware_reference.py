import unittest
import numpy as np
import attention_hardware_reference as hw

class HardwareGoldenTests(unittest.TestCase):
    def test_exp_dense_relative_bound_and_tail(self):
        maximum = 0.
        for x in np.linspace(-80,0,20001,dtype=np.float32):
            actual = float(hw.ref.value(hw.exp_neg_bits(hw.ref.bits(x))))
            expected = np.exp(float(x))
            maximum = max(maximum,abs(actual-expected)/expected)
        self.assertLessEqual(maximum,1e-5)
        self.assertEqual(hw.exp_neg_bits(0),0x3f800000)
        self.assertEqual(hw.exp_neg_bits(0x80000000),0x3f800000)
        self.assertEqual(hw.exp_neg_bits(hw.ref.bits(-81)),0)
        for x in (1,np.nan,np.inf,-np.inf):
            with self.assertRaises(ValueError):
                hw.exp_neg_bits(hw.ref.bits(x))

    def test_mathematical_exp_recovers_existing_reference(self):
        rng = np.random.RandomState(73)
        x = rng.normal(size=(4,33)).astype(np.float32)
        ws = [rng.normal(size=(33,33)).astype(np.float32) for _ in range(3)]
        wo = rng.normal(size=(5,33)).astype(np.float32)
        for mask in ([1,1,1,1],[0,1,0,1],[0,0,0,0]):
            for queries in (None,[3,0,3]):
                expected = hw.ref.attention(x,*ws,wo,3,False,np.asarray(mask,bool),queries)
                result = hw.attention(x,*ws,wo,3,False,mask,queries,
                    exp_fn=lambda bits:hw.ref.bits(np.float32(np.exp(hw.ref.value(bits)))))
                for name in expected:
                    self.assertEqual(result[name].tobytes(),expected[name].tobytes(),name)

    def test_approximate_reference_and_packing(self):
        rng = np.random.RandomState(30)
        x = rng.uniform(-.2,.2,(4,33)).astype(np.float32)
        ws = [rng.uniform(-.2,.2,(33,33)).astype(np.float32) for _ in range(3)]
        wo = rng.uniform(-.2,.2,(7,33)).astype(np.float32)
        cfg,_ = hw.isa.compile_program(4,33,3,11,7)
        result = hw.attention(x,*ws,wo,3)
        expected = hw.ref.attention(x,*ws,wo,3)
        actual_p = result['probabilities_bf16'].astype(np.uint32)<<16
        expected_p = expected['probabilities_bf16'].astype(np.uint32)<<16
        self.assertLessEqual(np.max(np.abs(actual_p.view(np.float32)-expected_p.view(np.float32))),0.00390625)
        packed = hw.pack_banks(cfg,result)
        for bank,payload in packed.items():
            data,scales = hw.isa.unpack(cfg['banks'][bank],payload)
            self.assertEqual(len(payload),cfg['banks'][bank]['capacity_bytes'])
        self.assertEqual(hw.isa.unpack(cfg['banks'][-1],packed[18])[0].tobytes(),result['output4'].tobytes())

if __name__ == '__main__':
    unittest.main()
