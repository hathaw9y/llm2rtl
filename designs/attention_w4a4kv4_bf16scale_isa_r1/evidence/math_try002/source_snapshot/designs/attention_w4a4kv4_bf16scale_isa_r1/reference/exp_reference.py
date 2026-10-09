"""Reproduce specified exp interpolation sequence using independent exact FP32 oracle."""
import math
from fp32_reference import alu,bits,decode
ROM=tuple(bits(2**(i/256)) for i in range(257))
def operation(op,a,b=0):
    result,error=alu(op,a,b)
    if error:raise ValueError('arithmetic error')
    return result

def exp_neg_bits(raw):
    x=decode(raw)
    if x>0:raise ValueError('positive exponential domain')
    if not x:return 0x3f800000
    if x < -80:return 0
    z=operation(1,raw,0x3fb8aa3b)
    floor=math.floor(decode(z))
    fraction=operation(0,z,bits(-floor))
    expanded=operation(1,fraction,0x43800000)
    index=min(255,math.floor(decode(expanded)))
    alpha=operation(0,expanded,bits(-index))
    delta=operation(4,ROM[index+1],ROM[index])
    product=operation(1,delta,alpha)
    result=operation(0,ROM[index],product)
    return result+(floor<<23)
