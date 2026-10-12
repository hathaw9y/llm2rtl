#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_gemm_wide_bank_integration_xsim}
evidence_dir="$design_dir/evidence/smollm2_gemm_wide_bank_integration/run_001"
mkdir -p "$run_dir" "$evidence_dir"
cd "$run_dir"
xvlog -sv \
  "$repo_dir/ip/infrastructure/bank/bank_ownership_table.sv" \
  "$repo_dir/ip/infrastructure/bank/bram_bank.sv" \
  "$repo_dir/ip/infrastructure/bank/uram_bank.sv" \
  "$design_dir/rtl/smollm2_bank_port_router_wide.sv" \
  "$design_dir/rtl/smollm2_bank_memories_wide.sv" \
  "$design_dir/rtl/smollm2_bank_subsystem_wide.sv" \
  "$design_dir/rtl/smollm2_gemm_systolic_wide_executor.sv" \
  "$design_dir/tb/tb_smollm2_gemm_wide_bank_integration.sv" \
  > "$evidence_dir/xvlog.log" 2>&1
xelab tb_smollm2_gemm_wide_bank_integration -L xpm \
  -s tb_smollm2_gemm_wide_bank_integration_sim \
  > "$evidence_dir/xelab.log" 2>&1
python3 "$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_gemm_wide_bank_integration_sim/xsimk" \
  'PASS smollm2_gemm_wide_bank_integration' \
  > "$evidence_dir/xsim.log" 2>&1
cat "$evidence_dir/xsim.log"
