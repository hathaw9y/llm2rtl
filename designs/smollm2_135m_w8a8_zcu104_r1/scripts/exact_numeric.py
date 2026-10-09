"""Exact finite IEEE binary32/BF16 boundary arithmetic, ties-to-even.

Transcendental functions are high-precision reference oracles only; their
hardware algorithm and approximation contracts have not been selected.
"""
from decimal import Decimal, localcontext
from fractions import Fraction
from functools import lru_cache


class NumericError(ValueError):
    pass


def round_even_ratio(numerator, denominator):
    q, r = divmod(numerator, denominator)
    return q + (2*r > denominator or (2*r == denominator and q & 1))


def pow2(exponent):
    return Fraction(1 << exponent) if exponent >= 0 else Fraction(1, 1 << -exponent)


def round_binary(value, fraction_bits, zero_sign=0):
    """Encode rational with eight exponent bits, including gradual underflow."""
    value = Fraction(value)
    sign = int(value < 0) if value else int(bool(zero_sign))
    value = abs(value)
    sign_word = sign << (fraction_bits+8)
    if not value:
        return sign_word
    exponent = value.numerator.bit_length()-value.denominator.bit_length()
    if value < pow2(exponent):
        exponent -= 1
    if exponent < -126:
        scaled = value / pow2(-126-fraction_bits)
        significand = round_even_ratio(scaled.numerator, scaled.denominator)
        return sign_word | significand  # rounding may reach the first normal
    if exponent > 127:
        return sign_word | (255 << fraction_bits)
    scaled = value / pow2(exponent-fraction_bits)
    significand = round_even_ratio(scaled.numerator, scaled.denominator)
    if significand == 1 << (fraction_bits+1):
        significand >>= 1
        exponent += 1
    if exponent > 127:
        return sign_word | (255 << fraction_bits)
    return sign_word | ((exponent+127) << fraction_bits) | (significand-(1 << fraction_bits))


@lru_cache(maxsize=65536)
def decode_binary(bits, fraction_bits):
    if type(bits) is not int or not 0 <= bits < 1 << (fraction_bits+9):
        raise NumericError("invalid floating-point encoding")
    exponent = (bits >> fraction_bits) & 255
    significand = bits & ((1 << fraction_bits)-1)
    if exponent == 255:
        raise NumericError("nonfinite tensor or scale")
    if exponent:
        significand |= 1 << fraction_bits
    value = significand*pow2((exponent if exponent else 1)-127-fraction_bits)
    return -value if bits >> (fraction_bits+8) else value


def finite32(bits):
    return ((bits >> 23) & 255) != 255


def f32(value, zero_sign=0):
    return round_binary(value, 23, zero_sign)


def bf16(value, zero_sign=0):
    return round_binary(value, 7, zero_sign)


def value32(bits):
    return decode_binary(bits, 23)


def value16(bits):
    return decode_binary(bits, 7)


def scale_value(bits):
    value = value32(bits)
    if value <= 0:
        raise NumericError("scale must be finite and positive")
    return value


def mul32(a, b):
    return f32(value32(a)*value32(b), (a ^ b) >> 31)


def div32(a, b):
    denominator = value32(b)
    if not denominator:
        raise NumericError("division by zero")
    return f32(value32(a)/denominator, (a ^ b) >> 31)


def add32(a, b):
    return f32(value32(a)+value32(b), (a & b) >> 31)


def mul16(a, b):
    return bf16(value16(a)*value16(b), (a ^ b) >> 15)


def add16(a, b):
    return bf16(value16(a)+value16(b), (a & b) >> 15)


def dynamic_scale(values, probability=False):
    decoded = [value16(x) for x in values]
    maximum = max(([max(x, 0) for x in decoded] if probability else
                   [abs(x) for x in decoded]), default=Fraction(0))
    return div32(f32(maximum), f32(127)) if maximum else f32(1)


def quantize(value_bits, scale_bits, probability=False):
    value16(value_bits)
    scale_value(scale_bits)
    quotient_bits = div32(value_bits << 16, scale_bits)
    lower, upper = (0, 127) if probability else (-127, 127)
    if not finite32(quotient_bits):
        return lower if quotient_bits >> 31 else upper
    quotient = min(Fraction(upper), max(Fraction(lower), value32(quotient_bits)))
    sign = -1 if quotient < 0 else 1
    return sign*round_even_ratio(abs(quotient.numerator), quotient.denominator)


def scaled_output(dot, a_scale, b_scale, score=False):
    scale_value(a_scale)
    scale_value(b_scale)
    scale = mul32(a_scale, b_scale)
    if score:
        if not finite32(scale):
            raise NumericError("nonfinite combined scale")
        scale = mul32(scale, f32(Fraction(1, 8)))
    if not finite32(scale):
        raise NumericError("nonfinite combined scale")
    result = mul32(f32(dot), scale)
    if not finite32(result):
        raise NumericError("nonfinite scaled GEMM result")
    stored = bf16(value32(result), result >> 31)
    value16(stored)  # finite BF16 output required
    return stored


def dequantize(value, scale):
    if not -127 <= value <= 127:
        raise NumericError("INT8 value outside the declared range")
    scale_value(scale)
    result = mul32(f32(value), scale)
    stored = bf16(value32(result), result >> 31)
    value16(stored)
    return stored


def decimal_value(value):
    return Decimal(value.numerator)/Decimal(value.denominator)


def reference_rsqrt32(bits):
    value = value32(bits)
    if value <= 0:
        raise NumericError("nonpositive RMS variance")
    with localcontext() as context:
        context.prec = 100
        return f32(Fraction(Decimal(1)/decimal_value(value).sqrt()))


def reference_exp32(bits):
    value = value32(bits)
    if value < -120:
        return f32(0)  # below half the smallest binary32 subnormal
    with localcontext() as context:
        context.prec = 100
        return f32(Fraction(decimal_value(value).exp()))


def reference_silu16(bits):
    value = value16(bits)
    if value > 120:
        return bits
    if value < -120:
        return 0x8000
    with localcontext() as context:
        context.prec = 100
        x = decimal_value(value)
        if x < 0:
            e = x.exp()
            result = x*e/(1+e)
        else:
            result = x/(1+(-x).exp())
        return bf16(Fraction(result), bits >> 15)
