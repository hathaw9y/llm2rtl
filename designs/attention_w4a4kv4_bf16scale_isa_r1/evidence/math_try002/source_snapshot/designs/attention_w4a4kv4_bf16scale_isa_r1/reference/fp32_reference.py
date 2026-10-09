"""Independent exact rational binary32 arithmetic (gradual underflow, RNE)."""
from fractions import Fraction
import struct

def decode(raw):
    sign=-1 if raw>>31 else 1
    exp=(raw>>23)&255; mant=raw&0x7fffff
    if exp==255: raise ValueError('nonfinite')
    if exp: mant|=1<<23;power=exp-150
    else: power=-149
    return sign*Fraction(mant)*(Fraction(2)**power)

def rne(x):
    q,r=divmod(x.numerator,x.denominator)
    return q+int(2*r>x.denominator or (2*r==x.denominator and q&1))

def encode(x,zero_sign=0):
    if not x: return zero_sign<<31
    sign=int(x<0); x=abs(x)
    e=x.numerator.bit_length()-x.denominator.bit_length()
    if x<Fraction(2)**e:e-=1
    p=max(-149,e-23);m=rne(x/(Fraction(2)**p))
    if m>=1<<24:m>>=1;p+=1
    if p>104:raise OverflowError('binary32 overflow')
    return (sign<<31)|((p+150)<<23 if m>=1<<23 else 0)|(m&0x7fffff)

def alu(op,a,b=0):
    try:
        if op==3:
            return encode(Fraction(a-(1<<32) if a>>31 else a)),False
        av,bv=decode(a),decode(b)
        if op in (0,4):
            bs=(b>>31)^(op==4); value=av+(-bv if op==4 else bv)
            zs=int(not value and bool(a>>31) and bool(bs))
        elif op==1:value=av*bv;zs=(a>>31)^(b>>31)
        elif op==2:
            if not bv:raise ValueError('divide zero')
            value=av/bv;zs=(a>>31)^(b>>31)
        else:raise ValueError('opcode')
        return encode(value,zs),False
    except (ValueError,OverflowError):return 0,True

def bits(x):return struct.unpack('>I',struct.pack('>f',x))[0]
def value(raw):return struct.unpack('>f',struct.pack('>I',raw))[0]
