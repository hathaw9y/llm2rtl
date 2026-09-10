---
name: parent-module-decomposition
description: Use when a parent agent interprets model, optimization, hardware spec, and design methodology inputs, asks clarification questions, decomposes an accelerator into minimal HDL module packets, assigns interfaces/resource budgets/tuning knobs, and performs pre-integration boundary review without writing HDL.
---

# Parent Module Decomposition

## Executable project contract gate

For this repository, read `contracts/README.md` before dispatch. Use
`python3 scripts/design_contracts.py init` to create a fresh design/revision
and module contract set. Fill the generated documents; do not treat template
nulls as defaults. After parent review, use `freeze --index ... --approved-by ...`
and pass the returned index path, SHA-256, design/revision and module ID to
every implementation, verification, integration and board worker. Run
`check --index ... --expected-sha256 ... --module ...` before each dispatch.
A missing or failed check blocks dispatch; never substitute `--fixture-only`.
Consumers must read the checked documents, not infer requirements from a PASS.
A revision change requires a new index/hash and affected-boundary re-verification.
Freeze approval is a recorded parent declaration, not tool-granted authority.
The bundled CLI automates contract handling only. Dispatch uses the agent tools
available in the user's environment; no E2E agent runner is bundled.

The parent turns a user target into minimal, independently verifiable HDL
packets. It does not write HDL.

The parent is the only orchestration agent. Every implementation,
verification, integration, board-wrapper, model-signoff, and board-signoff
worker is a Sub-agent. Sub-agents return evidence and failure feedback to the
parent. When `generation_strategy.recursive_subagents` is enabled,
implementation Sub-agents may split their root packet into child HDL contract
packets and request or spawn child implementation Sub-agents through an explicit
child contract manifest. Verification and signoff Sub-agents remain read-only
or evidence-only unless a packet explicitly reassigns them as implementation
agents.

## Input Interpretation

For model-based generation, first read `docs/model_graph_bringup.md`. The parent
must extract and review `model_graph.json` from the exact model code/config and
declared execution conditions before selecting module packets. Record graph
provenance, tensor/state semantics, unsupported paths and the scope of static
versus executed validation; config-only guesses are not a validated graph.
Always author a separate canonical `module_mapping.json` for a generation plan,
after graph review and before `bringup.json`. It owns module IDs, graph-node
assignments, sharing/fusion/splitting rationale, numeric transformations and
verification criteria, and architecture/memory decisions. It is a design plan,
not a frozen port/cycle contract. Only after explicit user approval of this exact
mapping, use `fpga-incremental-bringup` to generate the next plan;
`bringup.json.module_mapping` contains only the mapping path and SHA-256, never
a copied mapping inventory. Follow the format and executable planning gates in
`docs/model_graph_bringup.md` before stage contract freeze, dispatch and promotion.
Pass graph/mapping/bringup paths and hashes, stage ID and module IDs to workers.
The planning gate and contract gate are separate and both are required; neither
replaces semantic or numerical review. The contract CLI does not call the
planning checker automatically.
Keep incomplete planning as `draft` or `blocked` with explicit gaps. Do not invent
decisions to create a file, or generate new planning files for ordinary questions
or clarification-only intake. A standalone operator generation still produces
`module_mapping.json` with `scope: operator`, a hashed operator specification and
an applicability reason, not a fabricated full-model graph. Generate `bringup.json`
when that operator has a cumulative board bring-up plan.

## User Mapping Approval Gate

After constructing and reviewing `module_mapping.json`, present its exact
design/revision, path and SHA-256 with a readable summary of module roles,
sharing/fusion, numeric changes, memory/data movement, resource assumptions,
exclusions and unresolved risks. Ask the user explicitly whether to implement
this mapping. Set `parent_loop_state.json.status` to
`awaiting_user_mapping_approval` and pause. Do not generate `bringup.json`, even
as a draft, dispatch implementation or freeze implementation contracts while
awaiting the answer. Mapping revisions and read-only checks are allowed; a
draft `init` may prepare final storage paths but must not generate bring-up.

`reviewed` means Parent review, not user approval. Input clarification, the
original generation request, approval of this workflow rule, silence, structural
PASS or a sub-agent recommendation cannot approve a concrete mapping. Only
after an actual affirmative user response may the parent record
`module_mapping_approval.json` as defined in `docs/model_graph_bringup.md`.
Keep the mapping unchanged and bind the separate approval to its exact hash.
Pass the approval path/hash with every affected packet and use the planning
consumption gate's `--expected-approval-sha256` as well as mapping/plan pins.

If changes are requested, preserve prior artifacts, revise the mapping and
show the new version for approval again. A changed mapping or source/profile
reference invalidates the previous approval. Record and honor rejection or
revocation; never fabricate a user reply. Resolve final paths before asking so
relocation does not invalidate an approval. After approval, run the documented
`check_planning.py --before-bringup` gate with the mapping and approval hashes.
Only on PASS generate bring-up, binding its separate `module_mapping_approval`
reference to the checked approval. Then finalize stage contracts within that
mapping and dispatch only when the remaining
numeric, contract and prior hardware-checkpoint gates also pass.

Treat hardware design input as four axes, not one overloaded style:

- `compute_style`: PE/MAC architecture pattern, such as `simd_vector_mac`,
  `systolic_array`, `tiled_pe_array`, `time_multiplexed_pe`, or `scalar_fsm`.
- `execution_style`: scheduling/dataflow, such as `layer_by_layer`,
  `operator_by_operator`, `token_streaming`, `llm_decoder_streaming`,
  `prefill_decode_split`, or `batch_pipeline`.
- `memory_style`: weight, activation, and KV-cache movement/storage, such as
  `external_ddr_gptq_packed`, `external_ddr_streaming`, `uram_bram_tiled`, or
  `onchip_weight_storage`.
- `control_style`: controller structure, such as `hierarchical_fsm`,
  `layer_fsm`, `top_fsm`, or `microcoded_controller`.

These are structured slots, not closed enums. Preserve free-form
`architecture_brief`, `design_candidates`, `optimization_brief`,
`optimization_candidates`, and `extra_options` in parent artifacts and prompts.

## Clarification Gate

Before dispatch, ask focused questions if the parent cannot infer details that
affect module boundaries, interfaces, evidence, or budgets:

- quantization bit width, scale/zero-point/group layout, calibration data;
- pruning/sparsity format, storage layout, or sparse kernel requirement;
- compute fabric, memory movement, execution schedule, or control style;
- golden source, target clock, or resource budget.

Do not ask the user for numerical-error tolerances in the initial clarification
questions. This does not remove verification tolerances from module contracts
or permit weakening existing acceptance criteria.

Emit `input_clarification_questions.json` and stop with
`needs_clarification` instead of inventing missing methodology details.

## Hardware Resource Inventory

Keep device capacity and project budget separate:

- `device_*` fields describe board/device inventory.
- `max_*` fields describe the current design budget or tuning limit.

Load the matching hardware profile skill when the board or FPGA part has
profile-specific inventory or signoff rules. For example, use
`zcu104-xczu7ev-hardware` for ZCU104 / XCZU7EV targets. Do not hardcode
board-specific capacity numbers in this generic decomposition skill.

## Recursive Contract-First Strategy

When `generation_strategy.decomposition` is `recursive_contract_tree`, build
the architecture contract tree before assigning RTL:

- start with root packets for model control, decoder block, projection GEMM,
  non-GEMM datapaths, memory movement, and board shell boundaries;
- require each large root packet to either implement its RTL or emit a
  `child_contract_manifest` with smaller child packets;
- each child packet must preserve the parent numeric policy, blocked target
  dependencies, forbidden claims, parent boundary, and evidence paths;
- child contracts must define stable interfaces, memory residency, golden
  checks, simulation/OOC evidence, and the remaining recursion depth;
- resource reduction is not the first design step. Initial RTL is
  correctness-first and unconstrained by final ZCU104 ceilings; use OOC
  synthesis to measure real LUT/DSP/BRAM/URAM/timing pressure, then shrink only
  from measured bottlenecks;
- enforce final board resource ceilings only in the configured
  `resource_ceiling_phase`, normally `board_fit`.

For memory-heavy packets, require a memory residency contract. If weights or KV
cache may be preloaded, the parent or child packet must include BRAM/URAM
capacity math before rejecting preload; if external streaming is selected, the
packet must still define tile buffers, metadata queues, stream width, and
backpressure.

## Module Boundary Rules

Create a separate HDL packet when one or more criteria apply:

- mathematical class differs: GEMM/GEMV, RMSNorm, RoPE, softmax/control,
  residual add, KV-cache movement;
- data movement differs: packed weight streaming, activation buffering,
  KV-cache read/write, AXI/DDR movement;
- bottleneck differs: PE lanes, unpack/dequant bandwidth, softmax control,
  address generation, BRAM/URAM buffering;
- the unit can be independently verified with golden vectors, simulation, and
  timing/resource evidence when required;
- the function is reused across model locations.

Similar projections such as `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`,
`up_proj`, and `down_proj` should usually share a generic projection packet
with shape, address, and tiling parameters.

### Model scheduler role

A packet named or roled `model_scheduler` (or filling the `model_scheduler`
required visible role in a Block Design) must itself decide and sequence
work, not replay a flat command list a host program pre-computed. It must:

- own the complete multi-tile loop against whatever single-shot compute
  engine it drives (one `start` = one bounded tile), deciding in its own FSM
  which tile is next;
- directly issue the activation load start, weight load start, compute
  engine start, and output drain start in sequence from that FSM;
- accept one bounded per-job host descriptor (dimensions, DDR base
  addresses, bank policy) over its own `start`/`done` handshake, not a DDR
  pointer to an already-fully-expanded tile-by-tile command array.

A component whose own RTL is only a register file plus an instantiated
generic descriptor/command-list executor (no tile-loop or load/compute/drain
decision logic of its own) is an **infrastructure dispatcher**, not a model
scheduler, and must be named and scoped as one. Do not assign a
`model_scheduler` packet's implementation to "wrap the existing dispatcher
and rename it" — that is the forbidden pattern, not a shortcut. When the
target project defines a project-specific role contract for this (for
example `contracts/model_scheduler_role.json`), load and follow it; it takes
precedence over this generic description.

### Compute/memory-access boundary

A packet whose `agent_role` is a compute/arithmetic kernel (GEMM/GEMV,
RMSNorm, RoPE, softmax, SwiGLU, dequant, etc.) must terminate its own ports at
local memory only — internal registers, local BRAM/URAM bank-pool ports
reached through a router, or an equivalent local memory class. It must not own
AXI/DDR ports, an external-memory tensor port, or orchestrate a DDR-moving IP
(such as a DataMover Engine MM2S/S2MM command) directly. If the kernel's data must
come from or go to DDR, split that into a separate packet with its own
`agent_role` naming it as a data-movement/control orchestrator (not a compute
kernel), and have the compute packet consume/produce only local-memory-side
data. Do not let a compute packet's `does_not_claim`/`module_packet` list "DDR
fetch" as an omission while its interface still exposes DDR/AXI ports —
either the ports are absent, or the packet is not a compute packet.

## Module Packet Contents

Each module packet should define:

- task id, agent role, semantic op, and target coverage level;
- sub-agent type and recursive child policy, including whether the Sub-agent
  may spawn or request child HDL Sub-agents, whether a child contract manifest
  is required, and the remaining recursion depth;
- exact source/generator scope and files that must not be edited;
- interface contract, including clock/reset, `start`/`done`, direction-suffix-free
  public port names, packed vector
  layout, valid/ready streams when used, and memory/AXI ports;
- memory contract, including activation buffer storage, word width, depth,
  bank count, ping-pong policy, producer, and consumer;
- verification contract, including golden source, simulator, tolerances, and
  required evidence files;
- resource budget and resource objective;
- allowed tuning knobs such as PE lanes, tile size, buffer depth, memory word
  width, accumulator width, and pipeline stages;
- blocked target dependencies and forbidden claims.

## Pre-Integration Boundary Review

Before integration, the parent verifies that each child packet is still a
minimal reusable unit, not an accidental large subsystem or toy-only fixture.
Check that:

- interface and memory contracts are explicit and stable;
- module OOC synthesis evidence matches the active hardware spec and selected
  knobs;
- low utilization is explained by a throughput target or fixture-only waiver;
- no target-scale claim bypasses blocked checkpoint/model dependencies;
- integration can consume the selected child configuration without rewriting
  the child.

## Feedback Packet And Retry Plan

After each evidence refresh, the parent should emit:

- `parent_loop_state.json`: whether the parent should spawn ready sub-agents,
  collect missing failure detail, update a Skill, or wait for dependencies;
- `feedback_packet.json`: the exact feedback/assignment bundle sent to each
  ready or failed Sub-agent;
- `retry_plan.json`: which retries are allowed now, which are blocked until a
  Skill update or complete failure detail exists, and which parent action is
  required.

The parent decides all retries. A Sub-agent may suggest a retry through
`skill_update_candidate` or `subagent_result.json`. A recursive implementation
Sub-agent may also return a child contract manifest; the parent feedback loop
must record it, dispatch child work according to the configured recursion
policy, and keep blocked target claims intact until the full child tree passes.

## Resource Objective

After correctness and timing are proven, optimize for maximum useful hardware
utilization under configured limits. Do not treat low LUT/DSP/BRAM as success
for compute kernels unless throughput is already met or the packet is clearly a
fixture/control scaffold.
