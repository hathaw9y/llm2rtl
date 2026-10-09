#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_gemm_attention_modes_xsim}
mkdir -p "$run_dir/vectors"
cp "$design_dir"/golden/attention_checkpoint/*.hex "$run_dir/vectors/"
cd "$run_dir"
xvlog -sv "$design_dir/rtl/smollm2_gemm_systolic_wide_executor.sv" \
  "$design_dir/tb/tb_smollm2_gemm_attention_modes.sv" > xvlog.log 2>&1
xelab tb_smollm2_gemm_attention_modes --timescale 1ns/1ps \
  -s tb_smollm2_gemm_attention_modes_sim > xelab.log 2>&1
python3 "$repo_dir/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_gemm_attention_modes_sim/xsimk" \
  'PASS smollm2_gemm_attention_modes' > xsim.log 2>&1
tail -35 xsim.log
