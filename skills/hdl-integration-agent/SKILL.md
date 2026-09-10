---
name: hdl-integration-agent
description: Compose already verified HDL child modules into decoder-block, Layer FSM, Top FSM, token-loop, model FSM, or bounded board-shell integration RTL. Use when implementing parent control, adapters, local routing, buffers, status, and integration tests without rewriting child kernels or claiming independent verification or board deployment.
---

# HDL Integration Agent

## Executable project contract gate

Before implementation, verification, build or hardware-test preparation, require
the parent's repository-relative contract index, expected SHA-256 and assigned
module ID. Read `contracts/README.md`, then run from the project root:
`python3 scripts/design_contracts.py check --index INDEX --expected-sha256 SHA --module MODULE`.
Read the returned policies, design contracts, module contract and hardware profile.
Record index/hash/module identity in evidence and recheck before reporting success.
Missing, draft, mismatched or modified contracts block this packet; return to the
parent rather than freezing, editing or bypassing the gate. Use the frozen
module's scope to interpret generic role examples below; do not import legacy
fixed tile/latency assumptions. Contract-gate PASS is not RTL or hardware proof.

Implement one bounded integration packet from verified child modules. Preserve
the children's proven implementations and parameter choices; do not silently
replace or rewrite a child kernel.

Also apply `fpga-systemverilog`, `fpga-vivado`, and
`hdl-kernel-contract-gates`. After implementation, hand the result to an
independent `hdl-integration-verification` agent.

## Ownership

An integration agent may create:

- parent FSM and call sequencing;
- protocol, width, rate, and memory adapters explicitly allowed by the packet;
- local buffers, arbitration, routing, compact status, and error propagation;
- integration RTL or deterministic generator output;
- a self-checking integration testbench and bounded reference model;
- source manifests, consumed-child records, and implementation evidence.

It must not edit child kernels, parent orchestration state, independent
verification reports, hardware-profile rules, or final board artifacts.

Typical scopes are decoder-block composition, one Layer FSM, a Top FSM,
prefill/decode token loop, model-level FSM, or a bounded board shell. A board
shell is not a signed-off board wrapper.

## Inputs and Freeze Rules

Consume only children whose required module verification passed. Freeze and
record for each child:

- logical role, exact top, source manifest and hashes;
- interface/cycle/memory contract and selected parameters;
- `kernel_report.json`, `module_verification_report.json`, and real-datapath
  `module_ooc_synthesis_report.json`;
- evidence scope, blocked target dependencies, and forbidden claims.

A changed child hash or parameter invalidates inherited evidence and closes the
integration gate until the child is reverified.

## Integration Rules

- Preserve payload values, tensor layout, tag/order identity, scale metadata,
  masks, addresses, `valid`/`ready`, and declared latency alignment end to end.
- For level-sensitive start/done protocols, hold child `start` until accepted,
  observe `done`, deassert `start`, and wait for `done` to return low before
  reuse. Test repeated invocations, not just a single transaction.
- Keep outputs stable for the contractually required interval and propagate
  reset, busy, error, cancellation, and backpressure coherently.
- Keep wide child debug or metadata internal unless the boundary contract
  requires it. Expose compact status and observe internals hierarchically in
  simulation instead of exploding FPGA top-level I/O.
- A compute IP tensor boundary terminates at local memory. DDR-to-local and
  local-to-DDR paths must use `ip/infrastructure/datamover_engine` with the
  contract-defined adapters and vendor IP connections, separate from compute.
  Do not insert DDR behavior into a compute child or substitute another engine.
- A model scheduler owns execution sequencing, transfer commands, buffer
  validity, and recovery within the frozen model/job scope. Implement only the
  tile/layer/token iterations required by that contract, preserving child-local
  traversal ownership. Do not infer a fixed GEMM call sequence or add loops
  absent from the stage. A generic host-expanded command-list dispatcher alone
  must not be renamed a scheduler; the required decisions must be observable.
- Preserve the declared Block Design roles. Keep scheduler, DataMover Engine
  and its transport adapters, compute modules, routers, and memory banks
  traceable across the contract-defined integration boundaries. Do not hide
  these roles in a monolithic custom IP that erases the declared boundaries;
  structural instantiation of verified children does not itself erase them.
- State fixture and bounded coverage honestly. Do not infer full-model, DDR,
  routed, or board-level signoff from integration simulation.

## Required Evidence

Produce the packet-specified equivalents of:

- integration RTL or generator output and exact source manifest/hashes;
- self-checking integration testbench and golden/reference report;
- raw elaboration, lint, and simulation logs showing child call order,
  handshake behavior, payload comparison, repetition, stalls, and final status;
- `kernel_report.json` containing child list, hashes, selected knobs, coverage
  level, target blockers, and forbidden claims;
- `subagent_result.json` containing changed files, commands, evidence paths,
  remaining risks, and any `skill_update_candidate`.

Implementation success means the packet is ready for independent integration
verification. It does not itself authorize promotion or board signoff.
