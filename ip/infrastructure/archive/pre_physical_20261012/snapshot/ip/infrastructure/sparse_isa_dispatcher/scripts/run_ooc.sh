#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
out="${1:-$root/ip/infrastructure/sparse_isa_dispatcher/evidence/run_002/ooc_latest}"
out="$(realpath -m "$out")"
if [[ -e "$out" ]]; then echo "fresh output directory required: $out" >&2; exit 1; fi
mkdir -p "$(dirname "$out")"
work="$(mktemp -d /tmp/sparse_isa_dispatcher_ooc.XXXXXX)"
cd "$work"
/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado -mode batch \
 -log "${out}_vivado.log" -journal "${out}_vivado.jou" \
 -source "$root/ip/infrastructure/sparse_isa_dispatcher/scripts/ooc.tcl" -tclargs "$out"
