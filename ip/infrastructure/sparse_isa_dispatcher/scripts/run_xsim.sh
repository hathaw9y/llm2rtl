#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out="${1:-$root/ip/infrastructure/sparse_isa_dispatcher/evidence/run_002/xsim_latest}"
v="${VIVADO_BIN:-/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin}"
mkdir -p "$out";cd "$out";rm -rf xsim.dir .Xil
"$v/xvlog" --sv "$root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv" \
 "$root/ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv" \
 "$root/ip/infrastructure/sparse_isa_dispatcher/tb/tb_sparse_isa_dispatcher.sv" 2>&1 | tee xvlog.log
"$v/xelab" tb_sparse_isa_dispatcher -s sparse_isa_dispatcher_sim -timescale 1ns/1ps 2>&1 | tee xelab.log
python3 "$root/ip/infrastructure/sparse_isa_dispatcher/scripts/run_xsimk.py" "$out" "$out/xsim_direct.log"
