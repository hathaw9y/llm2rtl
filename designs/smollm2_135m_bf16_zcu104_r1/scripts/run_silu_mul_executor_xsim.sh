#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_silu_mul_executor_xsim}
mkdir -p "$run_dir/vectors"
cp "$design_dir"/golden/silu_mul_checkpoint/*.hex "$run_dir/vectors/"
cp "$design_dir/rtl/smollm2_silu_bf16_lut.mem" "$run_dir/"
cd "$run_dir"
xvlog -sv "$design_dir/rtl/smollm2_silu_mul_executor.sv" \
  "$design_dir/tb/tb_smollm2_silu_mul_executor.sv" > xvlog.log 2>&1
xelab tb_smollm2_silu_mul_executor -s tb_smollm2_silu_mul_executor_sim \
  --timescale 1ns/1ps > xelab.log 2>&1
python3 "${XSIM_RUNNER:-$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py}" \
  "$run_dir/xsim.dir/tb_smollm2_silu_mul_executor_sim/xsimk" \
  'PASS smollm2_silu_mul_executor' > xsim.log 2>&1
evidence="$design_dir/evidence/smollm2_silu_mul_executor/run_001"
mkdir -p "$evidence"
cp xvlog.log xelab.log xsim.log "$evidence/"
tail -25 xsim.log
