#!/usr/bin/env bash
set -euo pipefail
ip_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$(mktemp -d /tmp/datamover-integration.XXXXXX)"
simulator="${SIMULATOR:-xsim}"
sources=("${ip_dir}/rtl/datamover_engine_pkg.sv")
for module in fifo pipeline datamover_command_queue mm2s_channel s2mm_channel datamover_engine \
  axis_width_converter axis_width_down_converter axis_width_up_converter \
  mm2s_adapter s2mm_adapter bank_read_arbit bank_write_arbit bank_arbiter; do
  sources+=("${ip_dir}/rtl/${module}.sv")
done
echo "Integration artifacts: ${run_dir}"
sha256sum "${sources[@]}" "${ip_dir}/tb/integration_bank.sv" \
  "${ip_dir}/tb/tb_engine_integration.sv" > "${run_dir}/sources.sha256"
for bank in 32 128; do
  for latency in 1 3; do
    name="bank${bank}_lat${latency}"
    if [[ "${simulator}" == xsim ]]; then
      mkdir "${run_dir}/${name}"
      (
        cd "${run_dir}/${name}"
        xvlog -sv "${sources[@]}" "${ip_dir}/tb/integration_bank.sv" \
          "${ip_dir}/tb/tb_engine_integration.sv" > compile.log 2>&1
        xelab tb_engine_integration -s integration_sim -timescale 1ns/1ps \
          -generic_top "BANK_DATA_WIDTH=${bank}" -generic_top "BANK_READ_LAT=${latency}" \
          > elaborate.log 2>&1
        timeout 60s xsim integration_sim -runall > simulation.log 2>&1
        cat simulation.log
        rg -q '^PASS integration ' simulation.log
        if rg -q 'Fatal:|FATAL:|ERROR:' simulation.log; then exit 1; fi
      )
      continue
    elif [[ "${simulator}" != iverilog ]]; then
      echo "Unsupported SIMULATOR=${simulator}" >&2
      exit 2
    fi
    iverilog -g2012 -s tb_engine_integration \
      -Ptb_engine_integration.BANK_DATA_WIDTH="${bank}" \
      -Ptb_engine_integration.BANK_READ_LAT="${latency}" \
      -o "${run_dir}/${name}.vvp" "${sources[@]}" \
      "${ip_dir}/tb/integration_bank.sv" "${ip_dir}/tb/tb_engine_integration.sv" \
      > "${run_dir}/${name}_compile.log" 2>&1 || { cat "${run_dir}/${name}_compile.log"; exit 1; }
    timeout 30s vvp "${run_dir}/${name}.vvp" | tee "${run_dir}/${name}.log"
    rg -q '^PASS integration ' "${run_dir}/${name}.log"
  done
done
