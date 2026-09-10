---
name: hdl-integration-verification
description: Independently audit a composed HDL integration wave without editing its source. Use after decoder-block, Layer FSM, Top FSM, token-loop, model FSM, or board-shell implementation to verify child identity, dynamic connectivity, protocol behavior, payload correctness, source closure, and integration-level Vivado timing/resource evidence.
---

# HDL Integration Verification

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

Act as a source-read-only, evidence-producing integration verifier. You may run
simulation, lint, elaboration, and Vivado flows and write generated reports, but
must not edit RTL, tests, contracts, child implementations, or implementation
evidence.

Also apply `fpga-systemverilog`, `fpga-vivado`,
`hdl-kernel-contract-gates`, and `hdl-vivado-timing-closure`.

## Prerequisites

Before claiming a verification result, confirm:

- the integration implementation's self-checking simulation passed;
- each consumed child passed its required module verification;
- each real datapath child has current module OOC synthesis evidence;
- child source hashes, exact tops, and tuning knobs match the integration top;
- FPGA part, clock, memory widths, budgets, blockers, and forbidden claims
  match the active hardware specification.

Mark mismatched or incomplete evidence stale. Do not inherit a pass through a
changed source, parameter, generated file, or target identity.

## Dynamic Integration Audit

1. Elaborate the exact claimed top from a closed source manifest and confirm
   every required child is a real instance rather than a stub or behavioral
   stand-in.
2. Trace parent-to-child control and child-to-parent status dynamically. A test
   that hard-codes expected status without observing the child is insufficient.
3. Check start/accept/done/release behavior, repeated calls, reset, stalls,
   backpressure, cancellation or retry behavior where contracted, and output
   stability.
4. Compare end-to-end payloads and metadata against an independent reference,
   including tags, masks, scales, addresses, tensor ordering, numeric tails,
   and latency alignment.
5. Confirm compact external status is derived from real child activity while
   wide debug signals remain internal unless required.
6. Audit architectural roles: compute/local-memory boundaries, separate DDR
   movers, scheduler-owned iteration, and visible Block Design composition.
7. Verify that the stated coverage level matches what executed: fixture,
   decoder block, layer, token loop, model, or board shell. Preserve all
   forbidden higher-level claims.

## Integration-Level Vivado Evidence

Run or inspect Vivado synthesis for the composed integration top. Child OOC
reports are prerequisites, not substitutes, because the parent FSM, wiring,
adapters, buffers, fanout, boundary ports, and placement pressure can change
timing and resources.

Write `integration_synthesis_report.json` with:

- exact top, source identity, children, hashes, parameters, part, and clock;
- Vivado command, version, log, checkpoint, and generated report paths;
- setup, hold, pulse-width, constraints, DRC, and methodology status;
- aggregate LUT, FF, DSP, BRAM, URAM, I/O, and congestion assessment;
- evidence scope, pass/fail/blocked status, and retry recommendation.

If routed implementation is required by the packet, require routed evidence.
Small positive hold/setup margin or high I/O/fanout is a residual risk, not a
reason to summarize timing as merely "met."

## Findings and Failure Routing

Report P0/P1/P2/P3 findings before the summary. Route failures as follows:

- integration wiring, protocol, or parent-control defect:
  `hdl-integration-agent`;
- child functional or local contract defect: the responsible child
  implementation and `hdl-module-verification`;
- timing, fanout, congestion, or pipelining defect:
  `hdl-vivado-timing-closure` and the owning implementation agent;
- hardware-spec mismatch: invalidate affected evidence and request fresh child
  OOC plus integration synthesis.

Write `integration_verification_report.json` with status, findings, commands,
raw evidence paths, source identity, evidence scope, promotion eligibility,
remaining risks, forbidden claims, retry owner, and a complete
`skill_update_candidate` for any reusable failure. If Vivado is unavailable,
record the exact command and environment blocker; do not claim synthesis pass.
