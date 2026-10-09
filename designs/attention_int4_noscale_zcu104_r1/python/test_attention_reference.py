import unittest
import numpy as np
from attention_reference import attention, project, quantize, quantize_weights, bf16_value


class AttentionReferenceTest(unittest.TestCase):
    def setUp(self):
        rng = np.random.RandomState(41)
        self.x = rng.uniform(-1, 1, (3, 33)).astype(np.float32)
        self.weights = [rng.uniform(-.3, .3, shape).astype(np.float32)
                        for shape in [(32, 33)]*3+[(33, 32)]]

    def test_tail_groups_have_independent_scales(self):
        w = np.ones((1, 33), dtype=np.float32)
        w[0, 32] = 10
        q, scales = quantize_weights(w)
        self.assertNotEqual(int(scales[0, 0]), int(scales[0, 1]))
        a, s = quantize(np.ones((1, 33), dtype=np.float32))
        result = project(a, s, q, scales)
        expected = np.float32(0)
        for group, start in enumerate((0, 32)):
            dot = int(np.dot(a[0, start:start+32], q[0, start:start+32]))
            expected = np.float32(expected+np.float32(np.float32(dot)*np.float32(bf16_value(s[0])*bf16_value(scales[0, group]))))
        self.assertEqual(result[0, 0], expected)
        self.assertGreater(float(result[0, 0]), 40)

    def test_prefill_and_last_query_match(self):
        full = attention(self.x, *self.weights, heads=2)
        last = attention(self.x, *self.weights, heads=2, query_indices=[2])
        np.testing.assert_array_equal(full['output4'][-1:], last['output4'])
        np.testing.assert_array_equal(full['output_scale'][-1:], last['output_scale'])
        self.assertTrue(np.all(full['probabilities_bf16'][0, :, 1:] == 0))
        self.assertTrue(np.all(full['probabilities_bf16'][0, :, 0] == 0x3f80))
        self.assertEqual(full['k_scale'].shape, (3, 2))
        self.assertEqual(full['q_scale'].shape, (3,))

    def test_all_masked_returns_zero(self):
        result = attention(self.x, *self.weights, heads=2, valid_keys=[False]*3)
        self.assertTrue(np.all(result['output4'] == 0))
        self.assertTrue(np.all(result['output_scale'] == 0x3f80))
        self.assertTrue(np.all(result['probabilities_bf16'] == 0))

    def test_equal_logits_normalization(self):
        result = attention(self.x, np.zeros((32, 33)), self.weights[1], self.weights[2], self.weights[3], heads=2, causal=False)
        probs = result['probabilities_bf16']
        self.assertTrue(np.all(probs == probs[0, 0, 0]))
        self.assertLess(abs(3*float(bf16_value(probs[0, 0, 0]))-1), .01)

    def test_bad_shapes_rejected(self):
        with self.assertRaises(ValueError):
            attention(self.x, *self.weights, heads=3)


if __name__ == '__main__':
    unittest.main()
