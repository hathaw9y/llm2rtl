#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
out_dir="$design_dir/evidence/smollm2_rope_executor/run_001"
mkdir -p "$out_dir"
iverilog -g2012 -s tb_smollm2_rope_executor -o "$out_dir/rope.vvp" \
  "$design_dir/rtl/smollm2_rope_executor.sv" \
  "$design_dir/tb/tb_smollm2_rope_executor.sv"
for case_name in prefill decode prefill_tail; do
  case "$case_name" in prefill|prefill_tail) rows=32;; decode) rows=1;; esac
  for kind in q k; do
    vvp "$out_dir/rope.vvp" \
      +CASE="$design_dir/golden/rope_checkpoint/$case_name" \
      +KIND="$kind" +ROWS="$rows" | tee "$out_dir/${case_name}_${kind}.log"
  done
  vvp "$out_dir/rope.vvp" \
    +CASE="$design_dir/golden/rope_checkpoint/$case_name" \
    +KIND=k +KBANK=8 +ROWS="$rows" | tee "$out_dir/${case_name}_k_b8.log"
done
for negative in zero_rows too_many_rows wrong_bank nan_input; do
  vvp "$out_dir/rope.vvp" \
    +CASE="$design_dir/golden/rope_checkpoint/decode" \
    +KIND=q +ROWS=1 +NEGATIVE="$negative" | tee "$out_dir/error_${negative}.log"
done
