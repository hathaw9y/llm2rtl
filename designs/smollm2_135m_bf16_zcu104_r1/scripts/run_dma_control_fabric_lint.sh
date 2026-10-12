#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"
design_dir="$repo_dir/designs/smollm2_135m_bf16_zcu104_r1"
out_dir="$design_dir/evidence/smollm2_dma_control_fabric/run_007"
mkdir -p "$out_dir"

sources=(
  "$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/bank_subsystem/scripts/memory_wrapper_lint_stubs.sv"
  "$repo_dir/ip/infrastructure/bank/bank_ownership_table.sv"
)
for name in datamover_engine_pkg fifo pipeline axis_width_up_converter \
  axis_width_down_converter axis_width_converter mm2s_adapter s2mm_adapter \
  datamover_command_queue mm2s_channel s2mm_channel datamover_engine; do
  case "$name" in
    fifo|pipeline|axis_width_up_converter|axis_width_down_converter|axis_width_converter)
      sources+=("$repo_dir/ip/infrastructure/utils/$name.sv") ;;
    *) sources+=("$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/$name.sv") ;;
  esac
done
for name in smollm2_bank_port_router smollm2_bank_memories \
  smollm2_bank_subsystem smollm2_dma_bank_bridge smollm2_dma_engine_link \
  bank_tensor_state_tracker isa_command_dispatcher smollm2_dma_control_fabric; do
  sources+=("$design_dir/rtl/$name.sv")
done

verilator --lint-only --top-module smollm2_dma_control_fabric \
  -Wno-LITENDIAN -Wno-UNUSED -Wno-DECLFILENAME -Wno-TIMESCALEMOD \
  -Wno-WIDTH -Wno-UNDRIVEN "${sources[@]}" \
  >"$out_dir/verilator_lint.log" 2>&1
echo "PASS smollm2_dma_control_fabric Verilator lint"
