#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
run_dir=${1:-/tmp/smollm2_softmax_executor_xsim}
mkdir -p "$run_dir/vectors"
cp "$design_dir"/golden/softmax_checkpoint/*.hex "$run_dir/vectors/"
cd "$run_dir"
xvlog -sv -i "$design_dir/rtl" \
  "$design_dir/rtl/smollm2_softmax_executor.sv" \
  "$design_dir/tb/tb_smollm2_softmax_executor.sv" > xvlog.log 2>&1
xelab tb_smollm2_softmax_executor -L xpm --timescale 1ns/1ps \
  -s tb_smollm2_softmax_executor_sim > xelab.log 2>&1
python3 "$design_dir/../../ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_softmax_executor_sim/xsimk" \
  'PASS smollm2_softmax_executor' > xsim.log 2>&1
evidence_dir="$design_dir/evidence/smollm2_softmax_executor/run_001"
mkdir -p "$evidence_dir"
cp xvlog.log xelab.log xsim.log "$evidence_dir/"
tail -25 xsim.log
