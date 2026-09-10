---
name: fpga-incremental-bringup
description: Plan and coordinate cumulative FPGA accelerator bring-up from a working core through successive module additions, with a user-run hardware checkpoint before advancing each stage. Use when expanding a verified minimum accelerator rather than building all kernels before board integration.
---

# FPGA Incremental Bring-up

Own the cumulative stage plan and advancement decision. Use
`multi-agent-hdl-generation` and `parent-module-decomposition` for parent
coordination and module packets. The parent does not write RTL.

## Establish the stages

Read `docs/model_graph_bringup.md` before planning model-based stages. Consume
the parent's reviewed `model_graph.json` and mandatory `module_mapping.json`,
with exact model provenance and execution/validation scope. Derive stages from that mapping and
FPGA constraints, not a fixed operator list. Each stage must identify cumulative
graph coverage, new modules, reused modules, boundary inputs/outputs, reference
checks and a user hardware checkpoint. Preserve unsupported/blocked coverage.
The parent authors the canonical `bringup.json` before stage contract freeze
and dispatch. Its `module_mapping` field is only `{path, sha256}`; stage module
IDs refer to that single mapping source. Do not duplicate architecture, numeric
transformations or node-to-module assignments in the stage plan. Stage-specific
interfaces, buffers and budgets may refine the mapping without contradicting it.
Run the documented `scripts/check_planning.py` reference gate as well as the
contract gate before dispatch and promotion; pass graph/mapping/bringup hashes
and stage ID with every affected packet. A structural PASS is not permission to
advance past unresolved numerical evidence or a missing user hardware checkpoint.
Before generating any `bringup.json`, including a draft, require the user's
approval of the exact mapping, recorded separately in `module_mapping_approval.json`.
Parent `reviewed` status is insufficient. Without that approval, enter
`awaiting_user_mapping_approval`, present the mapping and stop before bring-up
generation, implementation dispatch and contract freeze. Run the documented
`check_planning.py --before-bringup` with exact mapping and approval hashes;
only after PASS author the plan and its separate `module_mapping_approval`
path/hash reference. Plan validation also requires these approval pins, even
without a stage selection. Mapping edits require a fresh user
decision, not just updated graph/plan hashes. Mapping approval does not replace
the separate user-run hardware checkpoints below.

Interpret the model, numeric policy, FPGA profile, execution scope, and final
resource budget before choosing the initial core. Do not universally select
GEMM or prescribe one fixed operator order. Select the smallest useful core
that can execute a real input-to-output transaction on the target board.

For this framework, if DDR-local transfers are used, include the bundled
DataMover Engine, required adapters, local memory, and minimum scheduler/control
in the initial composition, following the project transport policy.
Compute ports terminate at local memory. The scheduler owns execution and
necessary transfers; choose residency and reuse from the design contract,
not from an assumption that every compute invocation reloads DDR.

Plan interfaces, memory ownership, and resource headroom for the final model,
but implement one cumulative stage at a time. A stage adds a bounded capability
to the previous accepted composition. Isolated kernel fixtures may support
development but cannot substitute for the cumulative hardware checkpoint.

Record `bringup.json` following `docs/model_graph_bringup.md` with:

- model, hardware profile, final coverage and numeric acceptance criteria;
- ordered stage IDs, dependency, added capability and retained capabilities;
- selected core and reused module IDs from `module_mapping.json`, plus stage-specific interfaces, memory plan and resource estimates;
- implementation/verification packets and allowed changes;
- functional and regression tests, board coverage and user acceptance criteria;
- immutable source/build identity and evidence paths for each accepted stage.

Use existing project state paths where available; do not create a second
competing parent state. Keep stage outputs in distinct stage/build directories.
Keep the reviewed plan immutable; record live stage status and acceptance in
parent loop state and stage evidence keyed by plan hash and stage ID. Preserve
legacy `bringup_plan.json` when migrating, but do not maintain competing plans.

## Execute one stage

1. Freeze the previous accepted baseline: sources, parameters, contracts,
   constraints, build artifacts, test vectors and source/artifact hashes.
2. Route new kernels to `hdl-module-implementation` with relevant arithmetic
   Skills; route independent audits to `hdl-module-verification`.
3. Route cumulative composition to `hdl-integration-agent`, then independent
   checking to `hdl-integration-verification`. Use `fpga-systemverilog`,
   `hdl-kernel-contract-gates` and `fpga-vivado` as required by those roles.
4. Verify new functionality and retained behavior, including repeated jobs,
   memory reuse and common start/done release. Existing pulse interfaces need
   explicit verified adaptation under the project's interface contract.
5. Use `hdl-board-wrapper-signoff` and the hardware profile for the current
   stage's board composition; use `fpga-board-build-signoff` for matched
   production artifacts. A partial accelerator may have a stage-scoped board
   build, but must never be labeled as a full-model artifact.
6. Hand the exact build to `fpga-hardware-validation` to prepare user execution
   and collect the result. Enter `awaiting_user_hardware_validation` and tell
   the user which files and checks are ready. Do not advance dependent module
   implementation until that checkpoint is accepted.

This stage-scoped build path does not bypass required child or integration
verification and does not relax final full-model signoff gates.

## Advancement and recovery

Use stage states `planned`, `implementing`, `tool_verification`,
`building`, `awaiting_user_hardware_validation`, `accepted`, `failed`, and
`blocked`. Record user confirmation and its exact build/test scope when
transitioning to `accepted`. Silence, bitstream generation, and simulation
success are not hardware acceptance.

On failure, preserve the last accepted stage and failed-run evidence. Route
kernel errors to the implementation owner, integration errors to the
integration owner, timing errors through `hdl-vivado-timing-closure`, and
artifact/driver mismatches to their build/runtime owner. Prepare a new build
identity for changed artifacts, repeat affected regressions, and request user
hardware validation again. Do not overwrite the accepted baseline.

If an addition requires changing an existing interface or kernel, record the
design revision and affected descendants, then reverify them. Final resource
fit is required for every bitstream delivered for hardware testing, even if
early kernel exploration was correctness-first.

Update parent feedback and retry state after each result. Only generalizable
lessons go through `skill-creator`; stage-specific fixes stay in the design.
Full completion requires all requested capabilities and final cumulative user
hardware acceptance, with untested model sizes or modes explicitly recorded.
