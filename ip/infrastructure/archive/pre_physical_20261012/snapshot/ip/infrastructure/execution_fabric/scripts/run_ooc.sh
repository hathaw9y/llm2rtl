#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out="${1:-$root/ip/infrastructure/execution_fabric/evidence/run_001/ooc}"
work="${EXECUTION_FABRIC_OOC_WORK_DIR:-$(mktemp -d /tmp/execution_fabric_ooc.XXXXXX)}"
vivado="${VIVADO:-/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado}"
mkdir -p "$out" "$work";out="$(cd "$out" && pwd)";cd "$work"
"$vivado" -mode batch -log "$out/vivado.log" -journal "$out/vivado.jou" \
 -source "$root/ip/infrastructure/execution_fabric/scripts/ooc_synth.tcl" -tclargs "$out"
