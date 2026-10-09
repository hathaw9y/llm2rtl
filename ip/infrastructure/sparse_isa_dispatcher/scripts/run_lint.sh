#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
verilator --version
verilator --lint-only --sv -Wall -Wno-LITENDIAN -Wno-UNUSED -Wno-DECLFILENAME \
 --top-module sparse_isa_dispatcher \
 "$root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv" \
 "$root/ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv"
