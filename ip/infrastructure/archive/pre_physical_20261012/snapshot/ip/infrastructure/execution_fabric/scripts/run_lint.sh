#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
verilator --version
verilator --lint-only --sv -Wno-fatal -Wno-LITENDIAN --top-module execution_fabric \
 "$root/ip/infrastructure/bank_sparse_router/rtl/bank_config_pkg.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_engine_pkg.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/fifo.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_command_queue.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/mm2s_channel.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/s2mm_channel.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/status_decoder.sv" \
 "$root/ip/infrastructure/datamover_engine/rtl/datamover_engine.sv" \
 "$root/ip/infrastructure/stream_bank_adapters/rtl/mm2s_stream_bank_adapter.sv" \
 "$root/ip/infrastructure/stream_bank_adapters/rtl/s2mm_stream_bank_adapter.sv" \
 "$root/ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv" \
 "$root/ip/infrastructure/bank_sparse_router/rtl/bank_sparse_router.sv" \
 "$root/ip/infrastructure/bank_subsystem/scripts/memory_wrapper_lint_stubs.sv" \
 "$root/ip/infrastructure/bank_subsystem/rtl/bank_subsystem.sv" \
 "$root/ip/infrastructure/sparse_isa_dispatcher/rtl/sparse_isa_dispatcher.sv" \
 "$root/ip/infrastructure/execution_fabric/rtl/execution_fabric.sv"
