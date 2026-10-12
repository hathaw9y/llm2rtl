#!/usr/bin/env bash
set -euo pipefail
design_dir=$(cd "$(dirname "$0")/.." && pwd)
repo_dir=$(cd "$design_dir/../.." && pwd)
run_dir=${1:-/tmp/smollm2_dma_rms_gemm_rope_attention_board_probe_xsim}
mkdir -p "$run_dir"
cd "$run_dir"
mkdir -p vectors
cp "$design_dir"/golden/attention_checkpoint/*.hex vectors/
cp "$design_dir"/golden/add_checkpoint/*residual_expected_words.hex vectors/
cp "$design_dir"/golden/rmsnorm_checkpoint/{prefill,decode}_input_words.hex vectors/
cp "$design_dir"/golden/rmsnorm_checkpoint/gamma_words.hex vectors/
cp "$design_dir"/golden/rope_checkpoint/prefill/coeff_words.hex vectors/prefill_coeff_words.hex
cp "$design_dir"/golden/rope_checkpoint/decode/coeff_words.hex vectors/decode_coeff_words.hex
cp "$design_dir"/golden/rope_checkpoint/prefill/q_expected_words.hex vectors/prefill_q_expected_words.hex
cp "$design_dir"/golden/rope_checkpoint/decode/q_expected_words.hex vectors/decode_q_expected_words.hex
xvlog -sv -i "$design_dir/rtl" \
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
  "$design_dir/rtl/smollm2_gemm_systolic_wide_executor.sv" \
  "$design_dir/rtl/smollm2_rmsnorm_executor.sv" \
  "$design_dir/rtl/smollm2_rope_executor.sv" \
  "$design_dir/rtl/smollm2_softmax_executor.sv" \
  "$design_dir/rtl/smollm2_add_executor.sv" \
  "$design_dir/rtl/smollm2_gemm_dma_fabric_wide.sv" \
  "$design_dir/rtl/smollm2_dma_gemm_board_probe.sv" \
  "$design_dir/tb/tb_smollm2_dma_rms_gemm_rope_attention_board_probe.sv" \
  > xvlog.log 2>&1
xelab tb_smollm2_dma_rms_gemm_rope_attention_board_probe -L xpm --timescale 1ns/1ps \
  -s tb_smollm2_dma_rms_gemm_rope_attention_board_probe_sim > xelab.log 2>&1
python3 "${XSIM_RUNNER:-$repo_dir/ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/datamover_engine/scripts/run_xsimk.py}" \
  "$run_dir/xsim.dir/tb_smollm2_dma_rms_gemm_rope_attention_board_probe_sim/xsimk" \
  'PASS smollm2_dma_rms_gemm_rope_attention_board_probe' > xsim.log 2>&1
evidence_dir="$design_dir/evidence/smollm2_dma_rms_gemm_rope_attention_board_probe/run_001"
mkdir -p "$evidence_dir"
cp xvlog.log xelab.log xsim.log "$evidence_dir/"
tail -35 xsim.log
