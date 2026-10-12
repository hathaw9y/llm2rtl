#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out_dir="${1:-$repo_root/ip/infrastructure/bank_subsystem/evidence/run_001/ooc}"
work_dir="${BANK_SUBSYSTEM_OOC_WORK_DIR:-$(mktemp -d /tmp/bank_subsystem_ooc.XXXXXX)}"
vivado="${VIVADO:-/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado}"
mkdir -p "$out_dir" "$work_dir"
out_dir="$(cd "$out_dir" && pwd)"
work_dir="$(cd "$work_dir" && pwd)"
cd "$work_dir"
"$vivado" -mode batch -source "$repo_root/ip/infrastructure/bank_subsystem/scripts/ooc_synth.tcl" -tclargs "$out_dir" 2>&1 | tee "$out_dir/vivado.log"
