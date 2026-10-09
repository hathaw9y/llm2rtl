#!/usr/bin/env bash
set -euo pipefail

design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_dispatcher_xsim}
evidence_dir="$design_dir/evidence/isa_command_dispatcher/run_004"
mkdir -p "$run_dir" "$evidence_dir"
cd "$run_dir"

xvlog -sv \
  "$design_dir/tb/tb_isa_command_dispatcher.sv" \
  "$design_dir/rtl/isa_command_dispatcher.sv" \
  "$design_dir/rtl/bank_tensor_state_tracker.sv" \
  "$repo_dir/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv" \
  > "$evidence_dir/xvlog.log" 2>&1
xelab tb_isa_command_dispatcher -s tb_isa_command_dispatcher_sim \
  > "$evidence_dir/xelab.log" 2>&1
python3 "$repo_dir/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_isa_command_dispatcher_sim/xsimk" \
  'PASS isa_command_dispatcher integration' \
  > "$evidence_dir/xsim.log" 2>&1
cat "$evidence_dir/xsim.log"
