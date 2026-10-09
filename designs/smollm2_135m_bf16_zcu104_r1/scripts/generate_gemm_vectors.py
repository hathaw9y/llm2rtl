#!/usr/bin/env python3
"""Deterministic exact-rational BF16 GEMM vectors for the scalar RTL."""
from fractions import Fraction
from pathlib import Path
import random

OUT = Path(__file__).resolve().parents[1] / "golden" / "gemm_executor"


def bf16_value(bits: int) -> Fraction:
    sign = -1 if bits & 0x8000 else 1
    exp = (bits >> 7) & 255
    mantissa = bits & 127
    if exp == 0:
        integer, power = mantissa, -133
    else:
        integer, power = 128 + mantissa, exp - 134
    return sign * (Fraction(integer << power) if power >= 0 else
                   Fraction(integer, 1 << -power))


def round_bf16(value: Fraction) -> int:
    if value == 0:
        return 0
    sign = 0x8000 if value < 0 else 0
    target = abs(value)
    low, high = 0, 0x7f7f
    while low < high:
        middle = (low + high + 1) // 2
        if bf16_value(middle) <= target:
            low = middle
        else:
            high = middle - 1
    upper = min(low + 1, 0x7f7f)
    d_low = target - bf16_value(low)
    d_high = bf16_value(upper) - target
    chosen = upper if (d_high < d_low or (d_high == d_low and low & 1)) else low
    return sign | chosen


def main() -> None:
    rng = random.Random(135002)
    # Source rows 0..2, K=9. Command consumes rows 1..2.
    def sample() -> int:
        if rng.randrange(11) == 0:
            return 0
        sign = rng.randrange(2) << 15
        exponent = rng.randrange(121, 132)
        fraction = rng.randrange(128)
        return sign | (exponent << 7) | fraction

    act = [sample() for _ in range(27)]
    weight = [sample() for _ in range(45)]
    expected = []
    for row in range(1, 3):
        for column in range(5):
            dot = sum((bf16_value(act[row * 9 + k]) *
                       bf16_value(weight[column * 9 + k])
                       for k in range(9)), Fraction())
            expected.append(round_bf16(dot))
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in (("activation", act), ("weight", weight),
                       ("expected", expected)):
        (OUT / f"{name}.hex").write_text("".join(f"{x:04x}\n" for x in data))
    print("generated 2x9 @ 9x5 exact-rational BF16 golden vectors")


if __name__ == "__main__":
    main()
