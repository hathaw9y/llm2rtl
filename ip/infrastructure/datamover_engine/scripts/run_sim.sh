#!/usr/bin/env bash
set -euo pipefail
ip_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$(mktemp -d /tmp/datamover-engine-sim.XXXXXX)"
sources=("${ip_dir}/rtl/fifo.sv" "${ip_dir}/rtl/pipeline.sv"
  "${ip_dir}/rtl/axis_width_converter.sv" "${ip_dir}/rtl/axis_width_down_converter.sv"
  "${ip_dir}/rtl/axis_width_up_converter.sv" "${ip_dir}/rtl/mm2s_adapter.sv"
  "${ip_dir}/rtl/s2mm_adapter.sv")
for bank in 32 64 128; do
  iverilog -g2012 -s tb_mm2s_adapter -Ptb_mm2s_adapter.BANK_WIDTH="${bank}" \
    -o "${run_dir}/mm2s_${bank}.vvp" "${sources[@]}" "${ip_dir}/tb/tb_mm2s_adapter.sv"
  vvp "${run_dir}/mm2s_${bank}.vvp"
  for latency in 1 3; do
    iverilog -g2012 -s tb_s2mm_adapter -Ptb_s2mm_adapter.BANK_WIDTH="${bank}" \
      -Ptb_s2mm_adapter.READ_LAT="${latency}" -o "${run_dir}/s2mm_${bank}_${latency}.vvp" \
      "${sources[@]}" "${ip_dir}/tb/tb_s2mm_adapter.sv"
    vvp "${run_dir}/s2mm_${bank}_${latency}.vvp"
  done
done
iverilog -g2012 -s tb_support -o "${run_dir}/support.vvp" \
  "${sources[@]}" "${ip_dir}/tb/tb_support.sv"
vvp "${run_dir}/support.vvp"
iverilog -g2012 -s tb_command_queue -o "${run_dir}/command_queue.vvp" \
  "${ip_dir}/rtl/fifo.sv" "${ip_dir}/rtl/datamover_command_queue.sv" \
  "${ip_dir}/tb/tb_command_queue.sv"
vvp "${run_dir}/command_queue.vvp"
echo "Simulation artifacts: ${run_dir}"
