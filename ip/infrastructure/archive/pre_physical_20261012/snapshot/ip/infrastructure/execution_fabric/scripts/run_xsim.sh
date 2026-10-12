#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out="${1:-$root/ip/infrastructure/execution_fabric/evidence/run_001/xsim}"
vbin="${VIVADO_BIN:-/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin}"
mkdir -p "$out";out="$(cd "$out" && pwd)";cd "$out"
sources=(
 "$root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_engine_pkg.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/fifo.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_command_queue.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/mm2s_channel.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/s2mm_channel.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/status_decoder.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_engine.sv"
 "$root/ip/infrastructure/stream_bank_adapters/rtl/mm2s_stream_bank_adapter.sv"
 "$root/ip/infrastructure/stream_bank_adapters/rtl/s2mm_stream_bank_adapter.sv"
 "$root/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv"
 "$root/ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/bram_bank.sv"
 "$root/ip/infrastructure/datamover_engine/rtl/uram_bank.sv"
 "$root/ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv"
 "$root/ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv"
 "$root/ip/infrastructure/execution_fabric/rtl/execution_fabric.sv")
sha256sum "${sources[@]}" "$root/ip/infrastructure/execution_fabric/tb/tb_execution_fabric.sv" > sources.sha256
"$vbin/xvlog" -sv "${sources[@]}" "$root/ip/infrastructure/execution_fabric/tb/tb_execution_fabric.sv" > xvlog.log 2>&1
"$vbin/xelab" tb_execution_fabric -L xpm -s execution_fabric_sim -timescale 1ns/1ps > xelab.log 2>&1
python3 "$root/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" "$out/xsim.dir/execution_fabric_sim/xsimk" EXECUTION_FABRIC_XSIM_PASS > xsim.log 2>&1
rg -q 'EXECUTION_FABRIC_XSIM_PASS cases=3' xsim.log
cat xsim.log
