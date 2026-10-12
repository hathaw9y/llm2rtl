#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_gemm_systolic_wordbuf_xsim}
evidence_dir="$design_dir/evidence/smollm2_gemm_systolic_wordbuf_executor/run_001"
mkdir -p "$run_dir" "$evidence_dir"
python3 "$design_dir/scripts/generate_gemm_vectors.py" > "$evidence_dir/golden_generation.log"
cp "$design_dir"/golden/gemm_executor/*.hex "$run_dir"/
cp "$design_dir"/golden/gemm_model/*.hex "$run_dir"/
cp "$design_dir"/golden/gemm_systolic_model/*.hex "$run_dir"/
cd "$run_dir"
xvlog -sv "$design_dir/rtl/smollm2_gemm_systolic_wordbuf_executor.sv" \
  "$design_dir/tb/tb_smollm2_gemm_systolic_wordbuf_executor.sv" \
  > "$evidence_dir/xvlog.log" 2>&1
xelab tb_smollm2_gemm_systolic_wordbuf_executor --timescale 1ns/1ps \
  -s tb_smollm2_gemm_systolic_wordbuf_executor_sim > "$evidence_dir/xelab.log" 2>&1
python3 "$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_gemm_systolic_wordbuf_executor_sim/xsimk" \
  'PASS smollm2_gemm_systolic_wordbuf_executor' > "$evidence_dir/xsim.log" 2>&1
cat "$evidence_dir/xsim.log"
