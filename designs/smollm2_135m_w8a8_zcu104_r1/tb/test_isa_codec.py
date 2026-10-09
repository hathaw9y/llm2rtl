"""Wire-format and command-admission tests, not tensor validation."""
import random
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from isa_codec import (encode, decode, words, from_words, validate_command,
                       encode_weight_fragments)


class CodecTests(unittest.TestCase):
    def test_END_and_PS_word_order(self):
        self.assertEqual(encode("END"), 0)
        self.assertEqual(words(0x112233445566778899aabbccddeeff00),
                         (0xddeeff00, 0x99aabbcc, 0x55667788, 0x11223344))
        self.assertEqual(from_words((0xddeeff00, 0x99aabbcc, 0x55667788, 0x11223344)),
                         0x112233445566778899aabbccddeeff00)

    def test_DMA_matches_existing_wire_positions(self):
        record = encode("DMA_LOAD", (15, 0, 0), local_byte_offset=294912,
                        byte_count=48, ddr_address=0x58000000)
        expected = (1 << 124) | (15 << 120) | (294912 << 80) | (48 << 57) | (0x58000000 << 25)
        self.assertEqual(record, expected)
        self.assertEqual(validate_command(record)["fields"]["byte_count"], 48)

    def test_GEMM_positions_and_last_source_row(self):
        record = encode("GEMM_INT8", (13, 15, 12), n_start=48960,
                        n_total=49152, m_start=31, m_count=1, k=576, n_tile=192)
        expected = ((3 << 124) | (13 << 120) | (15 << 116) | (12 << 112) |
                    (48960 << 47) | (49152 << 31) | (31 << 25) | (1 << 19) |
                    (576 << 8) | 192)
        self.assertEqual(record, expected)
        validate_command(record)

    def test_reserved_bits_opcodes_and_unused_bank(self):
        for bad in [12 << 124, 1, (11 << 124) | 1, (3 << 124) | (1 << 100)]:
            with self.assertRaises(ValueError): decode(bad)
        with self.assertRaises(ValueError): encode("END", (1, 0, 0))
        with self.assertRaises(ValueError): encode("GEMM_INT8", (13, 3, 13))
        with self.assertRaises(ValueError): encode("DMA_LOAD", unknown=1)
        with self.assertRaises(ValueError): encode("DMA_LOAD", byte_count=1 << 23)

    def test_DMA_rejects_alignment_capacity_and_wrap(self):
        for fields in [dict(byte_count=0), dict(byte_count=16, ddr_address=1),
                       dict(byte_count=32, ddr_address=0xfffffff0),
                       dict(byte_count=32, local_byte_offset=36848)]:
            with self.assertRaises(ValueError):
                validate_command(encode("DMA_LOAD", (0, 0, 0), **fields))

    def test_embedding_aligned_scale_block_and_PL_lane(self):
        for row in range(32):
            for lane in range(4):
                record = encode("DMA_LOAD", (3, 0, 0), byte_count=16,
                                ddr_address=0x60000000,
                                local_byte_offset=294912+row*16, aux=1|(lane<<1))
                self.assertEqual(validate_command(record)["fields"]["aux"], 1|(lane<<1))
        with self.assertRaises(ValueError):
            validate_command(encode("DMA_LOAD", (15, 0, 0), byte_count=16,
                                    local_byte_offset=294912, aux=1))

    def test_conditional_scale_bank_acquisition(self):
        validate_command(encode("QUANTIZE", (5, 7, 8), mode=2, m_count=32, k=64, layer=29))
        validate_command(encode("QUANTIZE", (4, 0, 14), mode=1, m_count=1, k=64))
        validate_command(encode("DEQUANTIZE", (3, 0, 0), m_count=32, k=576))
        with self.assertRaises(ValueError):
            validate_command(encode("QUANTIZE", (5, 0, 8), mode=2, m_count=1, k=64))

    def test_probability_context_and_layer_limits(self):
        validate_command(encode("QUANTIZE", (10, 0, 13), mode=4,
                                m_count=32, k=1024, kv_len=1024, query_start=992))
        with self.assertRaises(ValueError):
            validate_command(encode("QUANTIZE", (10, 0, 13), mode=4,
                                    m_count=32, k=1024, kv_len=1024, query_start=993))
        with self.assertRaises(ValueError):
            validate_command(encode("QUANTIZE", (6, 7, 9), mode=3,
                                    m_count=1, k=64, layer=30))

    def test_B7_component_and_generation_rules(self):
        validate_command(encode("BANK_CONFIG", (7, 0, 0), profile=11,
                                rows=30, cols=64, component=2, generation=1))
        validate_command(encode("BANK_CONFIG", (7, 0, 0), profile=11,
                                rows=32, cols=64, position=992, component=1, generation=2))
        for fields in [dict(profile=4, rows=192, cols=1536, generation=0),
                       dict(profile=4, rows=193, cols=1536, generation=1),
                       dict(profile=4, rows=192, cols=1536, component=1, generation=1)]:
            with self.assertRaises(ValueError):
                validate_command(encode("BANK_CONFIG", (3, 0, 0), **fields))

    def test_attention_and_output_capacity(self):
        validate_command(encode("ATTN_SCORE_INT8", (14, 8, 10),
                                rows=32, kv_len=1024, query_start=992))
        with self.assertRaises(ValueError):
            validate_command(encode("ATTN_VALUE_INT8", (14, 9, 11), rows=1, kv_len=33, query_start=32))
        with self.assertRaises(ValueError):
            validate_command(encode("GEMM_INT8", (13, 3, 12),
                                    m_count=2, n_total=49152, k=576, n_tile=192))

    def test_binary_pingpong_and_fragments(self):
        fragments = encode_weight_fragments(49152, 576, 1, 0x10000000, 0x20000000, 12)
        work = [decode(v) for frag in fragments for v in frag if v]
        self.assertEqual(len(work), 1024)
        self.assertTrue(all(len(f) <= 16 and f[-1] == 0 for f in fragments))
        for i in range(256):
            config, payload, scale, gemm = work[4*i:4*i+4]
            self.assertEqual(config["banks"][0], (3, 15)[i%2])
            self.assertEqual(gemm["banks"], (13, (3, 15)[i%2], 12))
            self.assertEqual(scale["fields"]["local_byte_offset"], 294912)
            self.assertEqual(payload["fields"]["ddr_address"], 0x10000000+i*192*576)
            self.assertEqual(scale["fields"]["ddr_address"], 0x20000000+i*48)

    def test_roundtrip_random_DMA(self):
        rng = random.Random(808)
        for _ in range(200):
            record = encode("DMA_LOAD", (3, 0, 0), byte_count=rng.randrange(1, 100)*16,
                            ddr_address=rng.randrange(0, 1 << 24)*16,
                            local_byte_offset=rng.randrange(0, 100)*16)
            decoded = validate_command(record)
            self.assertEqual(encode(decoded["opcode"], decoded["banks"], **decoded["fields"]), record)
            self.assertEqual(from_words(words(record)), record)


if __name__ == "__main__":
    unittest.main()
