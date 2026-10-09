#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out_dir="${1:-$repo_root/ip/infrastructure/bank_subsystem/evidence/run_001/xsim_work}"
vivado_bin="${VIVADO_BIN:-/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin}"
mkdir -p "$out_dir"
cd "$out_dir"
rm -rf xsim.dir .Xil bank_subsystem_sim.pb xvlog.log xelab.log xsim.log
"$vivado_bin/xvlog" --sv \
  "$repo_root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv" \
  "$repo_root/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv" \
  "$repo_root/ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv" \
  "$repo_root/ip/infrastructure/datamover_engine/rtl/bram_bank.sv" \
  "$repo_root/ip/infrastructure/datamover_engine/rtl/uram_bank.sv" \
  "$repo_root/ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv" \
  "$repo_root/ip/infrastructure/bank_subsystem/tb/tb_bank_subsystem.sv" 2>&1 | tee xvlog.log
"$vivado_bin/xelab" tb_bank_subsystem -L xpm -s bank_subsystem_sim -timescale 1ns/1ps 2>&1 | tee xelab.log
python3 "$repo_root/ip/infrastructure/bank_subsystem/scripts/run_xsimk.py" "$out_dir" "$out_dir/xsim_direct.log"
