# Execution fabric template

This is a model-binding template, not a ready-to-synthesize fabric. The existing
`execution_fabric` is a verified example for four active banks and one GEMM
port set; its RTL and evidence remain unchanged.

After the user and Agent decide a model's ISA, modules and implementation
boundaries, fill `binding_template.json` in a new design revision. The binding
selects the bank inventory, owner roles, supported DMA bank ports, and every
compute opcode-to-executor route. Run `scripts/check_infrastructure_binding.py`
before generating the design-specific fabric RTL. The checker validates the
ISA/bank/route relationship; it does not generate RTL or prove wiring.

```bash
python3 scripts/check_infrastructure_binding.py --binding designs/<revision>/fabric_binding.json
```

Fill the [RTL scaffold](rtl/execution_fabric.sv.tpl) with explicit dispatcher,
DataMover Engine, bank ownership,
router/memory, stream adapters and executor instances. Reuse the pinned
`bank_ownership_table` and `datamover_engine` sources. The generated RTL must
receive its own source manifest, self-checking integration simulation, lint and
Vivado evidence. Board AXI BRAM Controller and vendor DataMover IP remain board
integration dependencies.

For native controller v4, choose the separately scoped directional bank contract.
Instantiate the generated native bank subsystem, whose ownership is internal,
and connect both acquire/release accepted vectors and subsystem
error to the controller. The scaffold's ownership region may document that
internal instance rather than creating a second exclusive ownership table.
Acquisition precedes executor valid; completion is buffered until safe accepted
release. The legacy binding contract above and existing exclusive fabrics are not
automatically migrated by the controller template update. Native design bindings
must record the directional contract and reverify generated control/data wiring.

Engines must receive and process all required memory responses and finish accepted writes
before emitting completion to release their banks; follow `contracts/common/engine_completion_contract.json`.
