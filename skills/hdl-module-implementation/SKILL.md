---
name: hdl-module-implementation
description: Use when an HDL implementation sub-agent writes or revises one bounded Verilog/SystemVerilog module packet, self-verifies it, emits kernel evidence, and runs module-level OOC synthesis for real datapath modules.
---

# HDL Module Implementation

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

Use this for one HDL packet at a time. Also apply `fpga-systemverilog`,
`fpga-vivado`, and `hdl-kernel-contract-gates`.

## Scope Rules

- Write only the assigned module/generator, task-specific tests, and evidence
  artifacts.
- Do not edit parent orchestration, dispatch, status, CLI, or unrelated tests.
- Do not weaken contracts, timing gates, forbidden-claim language, or existing
  regressions.
- Reuse the provided module packet contract rather than inventing ports or
  semantics.
- If the packet's module name or `agent_role` names it `model_scheduler`
  (or the project's role contract, e.g. `contracts/model_scheduler_role.json`,
  says so), implement the execution sequence and iterations assigned to it
  by the frozen model/job contract. The scheduler owns transfer commands,
  child-job sequencing, buffer validity, and error recovery within that scope;
  DDR transfers use the provided DataMover Engine. Derive the actual load,
  compute, drain, and repetition requirements from the contract, not a fixed
  GEMM sequence. Do not add weight loading, compute calls, or multi-tile loops
  to a stage that does not require them. Preserve the declared split between
  scheduler iteration and child-local traversal; compute children need not
  be single-tile. Host job configuration may parameterize execution, but a
  host-expanded command-list replayer alone is a dispatcher, not a model
  scheduler. If the packet leaves ownership ambiguous or requires that
  substitution, return a child-contract request to the Parent rather than
  inventing responsibilities or relabeling the dispatcher. Include a
  `skill_update_candidate` when the issue reflects a reusable guidance defect.
- If the packet's `agent_role` is a compute/arithmetic kernel, do not add
  AXI/DDR master ports, an external-memory tensor port, or direct
  orchestration of the DataMover Engine MM2S/S2MM path or its adapters,
  even if it would make the module more self-contained.
  The module's data ports terminate at local memory (registers, or local
  BRAM/URAM bank-pool ports reached through a router). If the packet as
  written requires DDR access to be useful, stop and return a
  `skill_update_candidate`/child-contract request asking the parent to split
  off a separate data-movement packet instead of adding the DDR path here.

## Recursive Child Packets

If the module packet or prompt says the Sub-agent may spawn or request child HDL
Sub-agents, use contract-first decomposition before writing a large monolithic
RTL block:

- split only when the root packet is too large to implement and verify as one
  bounded module;
- emit a `child_contract_manifest.json` or equivalent artifact that names each
  child task, interface, memory residency, numeric policy, evidence directory,
  allowed write scope, blocked target dependencies, and remaining recursion
  depth;
- preserve the root packet's quantization policy, forbidden claims, parent
  boundary, and required evidence in every child;
- do not claim the root packet passed until either the root RTL is implemented
  and verified or all required child results are integrated and verified;
- if recursive spawning is disabled for the packet, return the child manifest to
  the parent instead of launching ad hoc work.

## Required Interface

Follow the project module contract unless the packet explicitly extends it:

```systemverilog
input  logic aclk;
input  logic aresetn;
input  logic start;
output logic done;
```

`start` is sampled only when idle, `done` remains high until `start` is
deasserted, inputs stay stable while busy, and outputs stay stable while
`done` is high. Do not append `_i` or `_o` to public port names; direction is
expressed by the `input` or `output` declaration. Protocol-role prefixes such
as `m_axi_` and `s_axis_` remain valid. Packed vectors use little element order:
`element[idx] == vector[idx*WIDTH +: WIDTH]`.

## Implementation Evidence

Every packet must produce:

- generated `.sv` or generator change;
- testbench or generated testbench;
- Python/NumPy golden vector source or golden report;
- simulator or Verilator evidence;
- `kernel_report.json`;
- `subagent_result.json` listing changed files, commands, evidence, remaining
  risks, and any `skill_update_candidate`.

Real datapath modules must also produce `module_ooc_synthesis_report.json`.
Fixture/control scaffolds may waive OOC only when the report explicitly marks
the packet as fixture-only.

## Module OOC Synthesis

For real datapath modules, run Vivado OOC or equivalent module-level synthesis
for the configured FPGA part and clock. Report:

- command, Vivado version when available, part, and target clock;
- setup, hold, pulse-width, DRC, and methodology status;
- LUT, FF, DSP, BRAM, URAM, and I/O utilization;
- latency, initiation interval or start-to-done cycles, and throughput estimate
  for compute kernels;
- selected tuning knobs;
- resource assessment: `underutilized`, `near_budget`, `bandwidth_limited`,
  `timing_limited`, or `fixture_control_scaffold`.

The first real datapath implementation is correctness-first. Do not shrink PE
shape, tile buffers, metadata FIFOs, or payload lanes only to satisfy board
ceilings before OOC evidence exists. Resource reduction must cite measured
timing or utilization pressure and must preserve already-passed correctness,
interface, and memory-residency contracts.

If timing fails, preserve evidence and use `hdl-vivado-timing-closure` before
retrying. Adjust only contract-approved knobs.

## Failure-To-Skill

If the gate fails, do not hide the failure. Return a `skill_update_candidate`
with:

- failing command;
- symptom and log path;
- root-cause hypothesis;
- prevention rule;
- minimal regression check.

The parent applies accepted Skill updates to the repository copy under
`skills/<skill>/SKILL.md` and then syncs that copy into the runtime skill
directory with `scripts/sync_project_skills.py`.
