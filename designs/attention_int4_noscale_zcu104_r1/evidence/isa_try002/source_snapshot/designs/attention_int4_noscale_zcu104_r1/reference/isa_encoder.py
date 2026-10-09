"""128-bit ISA encoder for native MM2S/S2MM + QUANTIZE + END.

Compute operands are logical bank IDs. The count field is byte_count for DMA
and element_count for QUANTIZE; compute commands carry no raw memory addresses.
"""
END, MM2S, S2MM, QUANTIZE = 0, 1, 2, 3
FIELDS = {'opcode':(124,4),'operand0':(122,2),'operand1':(120,2),
          'operand2':(118,2),'local_offset':(86,32),'count':(63,23),
          'axi_address':(31,32)}
BANK_NUM = 3


def encode(opcode, operand0=0, operand1=0, operand2=0,
           local_offset=0, count=0, axi_address=0, validate=True):
    fields = dict(opcode=opcode,operand0=operand0,operand1=operand1,
                  operand2=operand2,local_offset=local_offset,count=count,axi_address=axi_address)
    result=0
    for name,(shift,width) in FIELDS.items():
        value=fields[name]
        if not isinstance(value,int) or value < 0 or value >= 1<<width:
            raise ValueError(f'{name} does not fit {width} bits')
        result |= value<<shift
    if validate:
        if opcode==END:
            if any(fields[k] for k in fields if k!='opcode'):
                raise ValueError('END has no operands or payload')
        elif opcode in (MM2S,S2MM):
            if not 0<=operand0<BANK_NUM or count==0:
                raise ValueError('DMA requires legal bank and positive byte count')
        elif opcode==QUANTIZE:
            if any(not 0<=bank<BANK_NUM for bank in (operand0,operand1,operand2)):
                raise ValueError('QUANTIZE requires legal logical bank IDs')
            if len({operand0,operand1,operand2})!=3:
                raise ValueError('QUANTIZE operand banks must be distinct')
            if not 1<=count<=256 or local_offset or axi_address:
                raise ValueError('QUANTIZE requires count1..256 and no raw address/offset')
        else:
            raise ValueError('unknown opcode')
    return result


def decode(word):
    if not isinstance(word,int) or not 0<=word<1<<128:
        raise ValueError('expected 128-bit instruction')
    return {name:(word>>shift)&((1<<width)-1) for name,(shift,width) in FIELDS.items()}


def mm2s(src_axi, bank, byte_count, local_offset=0):
    return encode(MM2S,operand0=bank,count=byte_count,axi_address=src_axi,local_offset=local_offset)


def s2mm(bank,dst_axi,byte_count,local_offset=0):
    return encode(S2MM,operand0=bank,count=byte_count,axi_address=dst_axi,local_offset=local_offset)


def quantize(src_bank,data_bank,scale_bank,elements):
    return encode(QUANTIZE,src_bank,data_bank,scale_bank,count=elements)


def quantize_program(elements,src_bank=0,data_bank=1,scale_bank=2,
                     source_axi=0x1000,data_axi=0x2000,scale_axi=0x3000):
    """DMA transfers whole padded128-bit words; QUANTIZE consumes only elements."""
    return [mm2s(source_axi,src_bank,((elements+3)//4)*16),
            quantize(src_bank,data_bank,scale_bank,elements),
            s2mm(data_bank,data_axi,((elements+31)//32)*16),
            s2mm(scale_bank,scale_axi,16),encode(END)]
