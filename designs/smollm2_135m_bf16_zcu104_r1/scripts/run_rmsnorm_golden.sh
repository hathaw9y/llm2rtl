#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
run_dir=${1:-/tmp/smollm2_rmsnorm_golden}
mkdir -p "$run_dir"
cd "$design_dir"
iverilog -g2012 -s tb_smollm2_rmsnorm_executor \
  -o "$run_dir/control.vvp" \
  rtl/smollm2_rmsnorm_executor.sv tb/tb_smollm2_rmsnorm_executor.sv
vvp "$run_dir/control.vvp" | tee "$run_dir/control.log"
iverilog -g2012 -s tb_smollm2_rmsnorm_golden \
  -o "$run_dir/golden.vvp" \
  rtl/smollm2_rmsnorm_executor.sv tb/tb_smollm2_rmsnorm_golden.sv
vvp "$run_dir/golden.vvp" +VECTOR_DIR=golden/rmsnorm | tee "$run_dir/random.log"
vvp "$run_dir/golden.vvp" +VECTOR_DIR=golden/rmsnorm_checkpoint/prefill | tee "$run_dir/prefill.log"
vvp "$run_dir/golden.vvp" +VECTOR_DIR=golden/rmsnorm_checkpoint/decode +ONLY_ONE_ROW | tee "$run_dir/decode.log"
vvp "$run_dir/golden.vvp" +VECTOR_DIR=golden/rmsnorm_checkpoint/large_input | tee "$run_dir/large_input.log"
