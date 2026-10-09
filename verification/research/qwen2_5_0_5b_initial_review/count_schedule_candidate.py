"""Count a proposed explicit-DMA lowering; not an executable ISA program."""
import json
from pathlib import Path
BASE = Path(__file__).resolve().parent

def projection(k, n, bias=False, store=False):
    kt, nt = k // 128, n // 128
    # Each residency tile: activation extract, weight load, scale load, GEMM.
    # Completion: bias load + bias/cast + insert, or cast + insert/store.
    return nt * (4 * kt + (3 if bias else 2))

qkv = projection(896, 896, True) + 2 * projection(896, 128, True)
o = projection(896, 896)
# Seven down PSUM banks stay resident. SCORE provides temporary FP32 gate/up.
ffn_chunk = 2 * (4 * 7 + 1) + 1 + 7 * 3
ffn = 38 * ffn_chunk + 7 * 2
# Two context loads per KV head; per Q head: extract/QK/softmax/PV/cast/insert.
attention = 2 * 2 + 14 * 6
subtotal = qkv + o + ffn + attention
lm_head = projection(896, 151936, store=True)
report = {
    'status': 'candidate_command_count_subtotal_not_validated_program',
    'assumptions': {'projection_tile': {'M_max':16,'N':128,'K':128},
                    'FFN_down_resident_PSUM_banks':7,
                    'FFN_gate_up_FP32_scratch':'SCORE bank, temporarily with projection layout',
                    'prefill_query_tile':16,'decode_rows':1},
    'per_layer': {'QKV':qkv,'O_projection':o,'FFN':ffn,'attention_head_work':attention,
                  'subtotal_excluding_norm_rope_residual_KV_stores_and_control':subtotal},
    'LM_head_last_row_only':lm_head,
    'decode_subtotal':24*subtotal+lm_head,
    'prefill512_subtotal':32*24*subtotal+lm_head,
    'capacity_only_chunk_lower_bound': {
        'decode': (24*subtotal+lm_head+1022)//1023,
        'prefill512': (32*24*subtotal+lm_head+1022)//1023},
    'omitted': ['embedding loads/dequant', 'RMSNorm gamma loads and compute',
                'RoPE table loads/rotation/layout', 'residual adds',
                'KV stores and layout', 'END records and DDR hazard boundaries'],
    'limitations': ['Counts enumerate the stated residency schedule only, without bit encoding or command acceptance simulation.',
                    'Not measured runtime performance, reference numerical evidence, or an optimized schedule.',
                    'Shared activation extraction across gate/up could change counts, but needs another FP32 scratch lifetime or rescheduling.']}
(BASE/'command_count_candidate.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
