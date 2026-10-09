#!/usr/bin/env python3
"""Pin DDR inputs and first-head attention output for the board probe."""
from pathlib import Path

design = Path(__file__).resolve().parents[1]
gold = design / 'golden/attention_checkpoint'
rms = design / 'golden/rmsnorm_checkpoint'
rope = design / 'golden/rope_checkpoint'
dest = design / 'dma_rms_gemm_rope_attention_board_probe'
dest.mkdir(exist_ok=True)


def words(path):
    return [int(x, 16) for x in path.read_text().split()]


def c_words(name, data):
    out = [f'static const uint32_t {name}[{len(data)}][4] = {{']
    for value in data:
        out.append('    {' + ', '.join(f'0x{(value>>(32*i))&0xffffffff:08x}u'
                                    for i in range(4)) + '},')
    return '\n'.join(out + ['};'])


def c_bf16(name, data):
    out = [f'static const uint16_t {name}[{len(data)}] = {{']
    for offset in range(0, len(data), 16):
        out.append('    ' + ', '.join(f'0x{x:04x}u' for x in data[offset:offset+16]) + ',')
    return '\n'.join(out + ['};'])


def first16(path, rows, words_per_row):
    packed = words(path)
    return [(packed[row*words_per_row+word] >> (16*lane)) & 0xffff
            for row in range(rows) for word in range(2) for lane in range(8)]


parts = ['#ifndef SMOLLM2_ATTENTION_BOARD_VECTORS_H',
         '#define SMOLLM2_ATTENTION_BOARD_VECTORS_H', '#include <stdint.h>']
for name, path in (
    ('prefill_input_words', rms/'prefill_input_words.hex'),
    ('decode_input_words', rms/'decode_input_words.hex'),
    ('gamma_words', rms/'gamma_words.hex'),
    ('q_weight_words', gold/'q_weight_tiles_words.hex'),
    ('prefill_coeff_words', rope/'prefill/coeff_words.hex'),
    ('decode_coeff_words', rope/'decode/coeff_words.hex'),
    ('prefill_k_words', gold/'prefill32_k_cache_words.hex'),
    ('decode_k_words', gold/'decode1_k_cache_words.hex'),
    ('prefill_v_words', gold/'prefill32_v_cache_words.hex'),
    ('decode_v_words', gold/'decode1_v_cache_words.hex'),
):
    parts.append(c_words(name, words(path)))
for case, rows, score_stride in (('prefill32', 32, 36), ('decode1', 1, 45)):
    for name, file, stride in (
        ('q', rope/('prefill' if rows == 32 else 'decode')/'q_expected_words.hex', 72),
        ('score', gold/f'{case}_score_words.hex', score_stride),
        ('prob', gold/f'{case}_probability_words.hex', score_stride),
        ('context', gold/f'{case}_context_words.hex', 72),
    ):
        parts.append(c_bf16(f'{case}_{name}_first16', first16(file, rows, stride)))
parts.append('#endif')
(dest/'vectors.h').write_text('\n\n'.join(parts)+'\n')
print(dest/'vectors.h')
