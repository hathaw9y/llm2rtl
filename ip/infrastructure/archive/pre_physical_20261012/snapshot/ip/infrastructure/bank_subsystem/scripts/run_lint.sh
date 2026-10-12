#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
verilator --version
verilator --lint-only --sv -Wno-fatal -Wno-LITENDIAN --top-module bank_subsystem \
  "$repo_root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv" \
  "$repo_root/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv" \
  "$repo_root/ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv" \
  "$repo_root/ip/infrastructure/bank_subsystem/scripts/memory_wrapper_lint_stubs.sv" \
  "$repo_root/ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv"
