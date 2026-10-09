import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'reference'))
from isa_encoder import *


class IsaEncoderTest(unittest.TestCase):
    def test_quantize_bit_positions_and_bank_zero(self):
        word=quantize(0,1,2,33)
        self.assertEqual(word,(3<<124)|(1<<120)|(2<<118)|(33<<63))
        self.assertEqual(decode(word),dict(opcode=3,operand0=0,operand1=1,operand2=2,
                                         local_offset=0,count=33,axi_address=0))

    def test_program_uses_padding_and_separate_scale_transfer(self):
        instructions=list(map(decode,quantize_program(33)))
        self.assertEqual([i['opcode'] for i in instructions],[MM2S,QUANTIZE,S2MM,S2MM,END])
        self.assertEqual([i['count'] for i in instructions],[144,33,32,16,0])
        self.assertEqual(instructions[2]['operand0'],1)
        self.assertEqual(instructions[3]['operand0'],2)

    def test_illegal_compute_operands_and_count_rejected(self):
        for args in [(0,0,2,1),(0,1,3,1),(0,1,2,0),(0,1,2,257)]:
            with self.assertRaises(ValueError):quantize(*args)
        with self.assertRaises(ValueError):encode(QUANTIZE,0,1,2,count=1,local_offset=1)
        with self.assertRaises(ValueError):encode(QUANTIZE,0,1,2,count=1,axi_address=0x1000)

    def test_dma_typed_fields_are_preserved(self):
        fields=decode(mm2s(0x12345678,2,64,17))
        self.assertEqual((fields['axi_address'],fields['local_offset'],fields['count'],fields['operand0']),
                         (0x12345678,17,64,2))

    def test_negative_vectors_can_encode_unknown_opcode(self):
        self.assertEqual(decode(encode(15,validate=False))['opcode'],15)
        with self.assertRaises(ValueError):encode(15)
        with self.assertRaises(ValueError):encode(16,validate=False)


if __name__=='__main__':unittest.main()
