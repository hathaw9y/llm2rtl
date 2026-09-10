---
name: hdl-module-verification
description: Independently audit one or more HDL module packets after implementation without editing their source. Use when deciding whether Verilog/SystemVerilog RTL may be promoted based on requirement and interface coverage, self-checking simulation, golden-vector comparison, source identity, kernel reports, Vivado out-of-context synthesis, timing/resource evidence, and the scope of hardware claims.
---

# HDL Module Verification

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

Act as a source-read-only verification agent. Inspect and, when permitted, rerun
verification commands, but do not repair RTL, tests, contracts, or implementation
evidence. Return actionable findings to the parent or implementation agent.

Also apply `hdl-kernel-contract-gates`, `fpga-systemverilog`, and `fpga-vivado`.
Apply `hdl-vivado-timing-closure` only to diagnose or route a timing failure; do
not perform the RTL fix while acting as the independent verifier.

## Inputs

Require the narrowest available module packet and its evidence:

- functional, interface, cycle, numeric, memory, and hardware contracts;
- DUT RTL, source manifest, source hashes, exact top, and selected parameters;
- self-checking testbench, golden vectors or reference model, and raw logs;
- `kernel_report.json` and `subagent_result.json`;
- `module_ooc_synthesis_report.json` plus raw Vivado reports for real datapaths;
- active FPGA part, target clock, resource budgets, memory width, and allowed
  tuning knobs.

Missing evidence is a finding, not permission to infer a pass.

## Audit Procedure

1. Bind every requirement to a test, assertion, report, or explicit blocker.
2. Confirm the source manifest and hashes identify the RTL actually compiled,
   simulated, linted, and synthesized.
3. Elaborate the exact claimed top and check source closure, parameters,
   generated sources, packages, and IP dependencies.
4. Audit the common handshake, packed-vector, width, signedness, reset, latency,
   tail, overflow, saturation, and stable-output contracts.
5. Check that self-checking simulation compares payload data against an
   independent reference rather than merely observing `done` or status flags.
6. Inspect or rerun DUT-only lint and module-level Vivado OOC synthesis. Child
   or wrapper synthesis is not a substitute for evidence tied to this DUT.
7. Compare timing and LUT/FF/DSP/BRAM/URAM claims with raw reports. Treat
   surprisingly low utilization as suspicious until hierarchy, optimization,
   and real arithmetic/memory inference are demonstrated.
8. Check architectural boundaries: compute kernels terminate tensor traffic at
   local memory, DDR movement remains separate infrastructure, and scheduler
   decisions are owned by the scheduler rather than hidden in a child kernel.
9. Classify evidence as toy, fixture-only, bounded integration, or target-scale.
   Preserve every blocked dependency and forbidden claim.

## Findings

Report findings first, ordered by severity:

- P0: functional error, stale or fabricated evidence, wrong DUT/part/clock,
  missing required proof, or an unsafe target-scale claim.
- P1: interface or cycle-contract mismatch, synthesis/timing/resource failure,
  incomplete OOC evidence, or an invalid architectural boundary.
- P2: missing important regression, weak payload checking, unclear tuning or
  resource claim, or a risky integration assumption.
- P3: cleanup, traceability, or documentation issue.

If there are no P0/P1/P2 findings, say so explicitly and list residual risks.

## Verification Result

Write `module_verification_report.json`, or return an equivalent structured
result when the packet specifies another path. Include:

- `status`: `passed`, `failed`, or `blocked`;
- exact module/top, configuration, source identity, and evidence scope;
- findings with severity, requirement, path, command, and raw evidence;
- commands inspected or run and their exit status;
- required-evidence presence and promotion eligibility;
- remaining risks, forbidden claims, and retry owner;
- a complete `skill_update_candidate` when a reusable failure pattern is found.

Do not turn an unavailable tool into a pass. Record the exact blocker and keep
promotion closed until fresh evidence exists.
