#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_dma_bank_bridge_xsim}
evidence_dir="$design_dir/evidence/smollm2_dma_bank_bridge/run_007"
mkdir -p "$run_dir" "$evidence_dir"
cd "$run_dir"
xvlog -sv \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/pipeline.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/fifo.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/axis_width_up_converter.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/axis_width_down_converter.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/axis_width_converter.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/mm2s_adapter.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/s2mm_adapter.sv" \
  "$repo_dir/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/bram_bank.sv" \
  "$repo_dir/ip/infrastructure/datamover_engine/rtl/uram_bank.sv" \
  "$design_dir/rtl/smollm2_bank_port_router.sv" \
  "$design_dir/rtl/smollm2_bank_memories.sv" \
  "$design_dir/rtl/smollm2_bank_subsystem.sv" \
  "$design_dir/rtl/smollm2_dma_bank_bridge.sv" \
  "$design_dir/tb/tb_smollm2_dma_bank_bridge.sv" \
  > "$evidence_dir/xvlog.log" 2>&1
xelab tb_smollm2_dma_bank_bridge -L xpm --timescale 1ns/1ps \
  -s tb_smollm2_dma_bank_bridge_sim \
  > "$evidence_dir/xelab.log" 2>&1
python3 "$repo_dir/ip/infrastructure/datamover_engine/scripts/run_xsimk.py" \
  "$run_dir/xsim.dir/tb_smollm2_dma_bank_bridge_sim/xsimk" \
  'PASS smollm2_dma_bank_bridge' \
  > "$evidence_dir/xsim.log" 2>&1
cat "$evidence_dir/xsim.log"
