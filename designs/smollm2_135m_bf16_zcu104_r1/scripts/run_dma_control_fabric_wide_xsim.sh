#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_dma_control_fabric_wide_xsim}
evidence_dir="$design_dir/evidence/smollm2_dma_control_fabric_wide/run_001"
mkdir -p "$run_dir" "$evidence_dir"
cd "$run_dir"
xvlog -sv \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/datamover_engine_pkg.sv" \
  "$repo_dir/ip/infrastructure/utils/fifo.sv" \
  "$repo_dir/ip/infrastructure/utils/pipeline.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_width_converter_removal_20261012/snapshot/ip/infrastructure/utils/axis_width_up_converter.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_width_converter_removal_20261012/snapshot/ip/infrastructure/utils/axis_width_down_converter.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_width_converter_removal_20261012/snapshot/ip/infrastructure/utils/axis_width_converter.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/mm2s_adapter.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/s2mm_adapter.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/datamover_command_queue.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/mm2s_channel.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/s2mm_channel.sv" \
  "$repo_dir/ip/infrastructure/archive/pre_reference_integrated_20261012/snapshot/ip/infrastructure/datamover/datamover_engine.sv" \
  "$repo_dir/ip/infrastructure/bank/bram_bank.sv" \
  "$repo_dir/ip/infrastructure/bank/uram_bank.sv" \
  "$repo_dir/ip/infrastructure/bank/bank_ownership_table.sv" \
  "$design_dir/rtl/smollm2_bank_port_router_wide.sv" \
  "$design_dir/rtl/smollm2_bank_memories_wide.sv" \
  "$design_dir/rtl/smollm2_bank_subsystem_wide.sv" \
  "$design_dir/rtl/smollm2_dma_bank_bridge.sv" \
  "$design_dir/rtl/smollm2_dma_engine_link.sv" \
  "$design_dir/rtl/bank_tensor_state_tracker.sv" \
  "$design_dir/rtl/isa_command_dispatcher.sv" \
  "$design_dir/rtl/smollm2_dma_control_fabric_wide.sv" \
  "$design_dir/tb/tb_smollm2_dma_control_fabric_wide.sv" \
  > "$evidence_dir/xvlog.log" 2>&1
xelab tb_smollm2_dma_control_fabric_wide -L xpm --timescale 1ns/1ps \
  -s tb_smollm2_dma_control_fabric_wide_sim > "$evidence_dir/xelab.log" 2>&1
python3 "$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_dma_control_fabric_wide_sim/xsimk" \
  'PASS smollm2_dma_control_fabric_wide' > "$evidence_dir/xsim.log" 2>&1
cat "$evidence_dir/xsim.log"
