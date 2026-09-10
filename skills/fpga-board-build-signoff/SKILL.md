---
name: fpga-board-build-signoff
description: Package, synthesize, implement, and sign off FPGA board designs while producing matched BIT, HWH, XSA, and routed evidence. Use for board integration, Vivado project/run automation, resource and timing closure, congestion analysis, artifact validation, one-shot production builds, or recovery from failed/partial runs. Requires a separate hardware profile for board, part, clocks, interfaces, capacities, tool version, and deployment policy.
---

# FPGA Board Build and Signoff

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

## Purpose

Turn a verified HDL integration packet into board artifacts without inheriting unproven results from previous runs. Treat Vivado observations as stage-specific, preserve every terminal run, and publish only mutually consistent artifacts from an approved run.

This skill is board-agnostic. Load the applicable hardware profile or board documentation for the exact part, clock, PS/PL interface, address map, resource capacity, and signoff thresholds.

## Required inputs

- HDL packet from `$hdl-generation-verification` with source manifest and tests;
- exact board/part and tool version;
- top module, IP packaging rules, constraints, clocks, resets, address map, AXI widths;
- resource limits and intended BRAM/URAM/DSP/LUTRAM mapping;
- timing, route, DRC, methodology, and congestion acceptance criteria;
- required output set and deployment classification policy.

## Workflow

### 1. Freeze readiness before ownership

Before creating a run owner or invoking Vivado:

- verify tool version using the complete output, an anchored expected banner, return code zero, and exactly one match;
- verify free space against a declared minimum;
- prove fresh owner, run, staging, and promotion paths;
- verify exact source, constraint, helper, forensic, and packet hashes;
- prove transitive source closure and repository/package elaboration;
- record the intended number of synth/implementation launches and jobs.

All readiness failures must occur before owner creation and leave production paths absent.

### 2. Build from controlled inputs

Prefer a fresh from-source project after RTL, packaging, block-design, constraint, or address-map changes. A resume is eligible only when the prior terminal evidence proves the checkpoint complete, current, uncontaminated, and appropriate for the remaining steps.

Do not resume a consumed one-shot project after partial packaging or synthesis unless an audited recovery plan explicitly permits it. Clone only a typed, exhaustive, hash-bound tree; reject symlinks and non-regular objects, and verify the clone again before Vivado.

### 3. Verify board contracts using object semantics

For Vivado Tcl collections:

- guard cardinality before `lindex`, `get_property`, or dependent queries;
- prefer object properties and exact set equality over fragile hierarchical glob strings;
- distinguish logical nets, hierarchical aliases, physical replicas, and segment-resolved drivers;
- normalize numeric properties such as hexadecimal values, underscores, and binary unit suffixes before comparison;
- record raw and normalized values.

When a property value begins with `-`, set related run properties in one
`set_property -dict [list ...] $object` transaction and read every value back
before launching a run. Exercise the exact production setter against a real,
on-disk, zero-progress scratch project; a Tcl syntax-only test is insufficient.

Do not compare `current_design` or a design object's `NAME` with the RTL top.
Require exactly one design object, compare its `TOP` and `PART` properties, and
validate the unique root cell's `NAME`, `REF_NAME`, and `ORIG_REF_NAME`
separately.

Preserve Vivado's typed design collection when checking that identity. In a
Vivado 2025.2 linked board design, `lindex [current_design] 0` converted the
object to a name such as `design_1`, and `get_property TOP` then failed with
Common 17-161. Store `[current_design]` directly, check its cardinality with
`llength`, and query properties on the original collection; do not pass it
through a generic singleton helper that returns `lindex`. Verify this with a
read-only probe in the actual design context. If only report collection fails
after completed synthesis, preserve the failed invocation and checkpoint and
use an explicitly audited report-only recovery before deciding to resynthesize.

Never transplant a selector from another checkpoint without a read-only probe against the current design context.

### 4. Apply stage-specific gates

Post-synthesis and post-route reports can have different sections, row cardinalities, resource counts, reset topology, and check-timing results. Maintain separate contracts for each stage.

At minimum, observe and bind:

- exact top, hierarchy singletons, source/package identity;
- clocks, periods, clock sources, resets, and all check-timing categories;
- LUT, FF, LUTRAM, BRAM18/36, URAM, DSP, and scoped hierarchy resources;
- setup, hold, pulse-width, failing endpoints, and unconstrained paths;
- placed/routed net counts, route errors, and functional unplaced cells;
- congestion for every required report section and all forbidden levels;
- severe DRC and methodology findings.

Parse actual reports, not reconstructed summaries. Use exact row identity/cardinality and explicit malformed/missing/duplicate/wrong-value tests.

Anchor numbered report bodies rather than counting headings that may also occur
in a table of contents. Make parsers stage-aware: a placed/pre-route congestion
report may contain only the Placer body, while a routed report must contain the
required Placer and Router bodies. Accept Vivado dotted leaders only with exact
row cardinality, and reject unknown or malformed row-like lines. Separate
constant pseudo-cells from functional unplaced cells and require the latter to
be zero.

### 5. Treat congestion as signoff

Do not infer congestion closure from timing or successful routing. Parse the specified placer and router congestion sections independently. If policy requires no Level 5 or higher windows, any L5 row makes the result diagnostic/nonqualified even when timing and bit generation pass.

The sentence "no congestion windows above level 5" does not prove that Level 5
is absent. Request an L5-inclusive report, such as
`report_design_analysis -congestion -min_congestion_level 5` when supported,
and fail closed when the required level is not observable.

When optimizing congestion, first inspect actual window coordinates, hierarchy occupancy, hard-memory columns, high-fanout net geography, and timing paths. Prefer low-risk placement spreading or local replication that preserves latency and ABI. Re-run global congestion checks to ensure the hotspot was not merely relocated.

### 6. Bind same-run artifacts

Production publication must bind the required artifact set from the same accepted design:

- standalone BIT byte-equals the BIT embedded in XSA;
- required HWH files have exact identity, semantics, and byte/hash equality with their XSA members;
- routed DCP and reports correspond to the run being classified;
- XSA archive has the exact allowed member set, unique safe regular entries, no traversal, nesting, duplicates, or symlinks;
- part, top, address map, ABI, clock, and interfaces match the hardware profile.

Renaming a `.hwh` file does not repair a semantic mismatch. PYNQ generally expects a matching BIT/HWH pair; use the top-level HWH selected by the driver and keep auxiliary HWH files as evidence when required.

### 7. Publish atomically

Write artifacts and reports to a temporary staging directory. Reparse and rehash the staged copy, generate payload and recursive manifests, write the classifier and READY marker last, then rename atomically within the same filesystem. Revalidate packet and forensic manifests immediately before promotion.

A validation-only checker must perform no writes and must reject missing files
instead of recreating them. Test this with content, type, inventory, and mtime
snapshots. Immediately before the atomic rename, revalidate authority, packet,
runner, approval, source/forensic closure, payload, typed tree, classifier, final
manifest, owner, and READY; make the final local validation no-write and adjacent
to the rename.

The final classifier must state whether the result is production/deployable or diagnostic/nonqualified. Never relabel a diagnostic build by copying or renaming files.

## Recovery after failure

Every invocation consumes its one-shot token, even when it fails before synthesis. Preserve owner, invocation, raw logs, status, classifier, project/run state, checkpoints, artifacts, and an exhaustive typed inventory. Identify the precise failure class:

- functional/RTL or source closure;
- selector/property-format false negative;
- stage-specific parser mismatch;
- synthesis, timing, route, congestion, DRC, or methodology failure;
- artifact/XSA/HWH mismatch;
- infrastructure failure such as ENOSPC or signal termination.

Use a fresh version, token, owner, run root, staging path, and promotion path. Add a regression that reproduces the old failure using the actual frozen report or checkpoint before authorizing recovery.

## Common failure patterns

Read [references/failure-patterns.md](references/failure-patterns.md) before freezing a production packet or designing a recovery run.
