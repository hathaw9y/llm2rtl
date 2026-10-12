// Agent-generated source template. Replace every @...@ section after the
// model-specific fabric binding passes check_infrastructure_binding.py.
// This file is intentionally not synthesizable before those sections are filled.
module @TOP_MODULE@ (
@TOP_PORTS@
);
  // Declare typed command, DMA status, ownership, bank-data and executor wires.
@SHARED_SIGNALS@

  // Generated from the discussed ISA. Decode and response identity must match
  // every compute_routes entry in the checked binding.
@DISPATCHER_INSTANCE@

  // Reuse the pinned DataMover Engine source and bind all active DMA banks.
@DATAMOVER_INSTANCE@

  // Reuse the pinned bank_ownership_table source. BANK_NUM and
  // PORT_ROLE_WIDTH come from the checked binding, not fixed GEMM defaults.
@OWNERSHIP_INSTANCE@

  // Bind the model-specific bank router and physical BRAM/URAM inventory.
@BANK_SUBSYSTEM_INSTANCE@

  // Instantiate precisely the load/store adapter inventory in the binding.
@DMA_ADAPTER_INSTANCES@

  // Instantiate precisely the opcode executor routes in the binding.
@EXECUTOR_INSTANCES@

  // Assert handshake-to-acquire, matched-completion-to-release, capability,
  // and no-lost-response invariants in the generated implementation.
@INTEGRATION_ASSERTIONS@
endmodule
