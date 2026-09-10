---
name: multi-agent-hdl-generation
description: Use when coordinating a parent Codex agent that decomposes model-to-HDL accelerator work into sub-agents, routes each agent to the right HDL/verification/signoff skill, and enforces that the parent does not hand-write Verilog/SystemVerilog.
---

# Multi-Agent HDL Generation

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
The bundled CLI automates contract handling only. The parent coordinates
workers using the agent tools available in the user's environment; no E2E
agent runner is bundled.

This is the router skill for the llm2rtl agent framework. Keep detailed
role behavior in the role-specific skills listed below.

## Parent Invariants

- The parent agent coordinates; it must not hand-write HDL kernels,
  integration FSM RTL, or board-wrapper RTL.
- The parent is the only orchestrator. Every non-parent worker is a Sub-agent,
  including HDL implementation, verification, integration, board-wrapper,
  model-signoff, and board-signoff workers.
- With `generation_strategy.recursive_subagents: true`, implementation
  Sub-agents may recursively split an oversized HDL packet into child contract
  packets and request or spawn child implementation Sub-agents only through the
  packet's explicit recursive child policy. They must return the child contract
  manifest and evidence to the parent feedback channel. Verification, model
  signoff, board-wrapper, and board-signoff agents do not recursively spawn work
  unless explicitly reassigned as implementation agents.
- The parent owns input interpretation, module packet definitions, prompt
  packets, dispatch order, feedback packets, evidence collection, retry
  routing, and Skill updates after reusable failures.
- HDL, integration, board-wrapper, and verification work is delegated to
  sub-agents with narrow scopes and explicit evidence requirements.
- Codex-only verification, model signoff, board-wrapper route evidence, and
  board signoff may be queued for external Codex/Vivado-capable sub-agents
  when the package runtime cannot execute them directly.
- A dependent wave cannot start until its implementation evidence and required
  verification gate pass.

## Skill Routing

Load the smallest role-specific skill that matches the current agent:

- Parent decomposition and module packet definition:
  `parent-module-decomposition`.
- Cumulative core-first implementation with user hardware checkpoints:
  `fpga-incremental-bringup`. Build and validate each partial stage at its
  declared coverage; the full-target gates below apply to full-model claims,
  not to these explicitly stage-scoped builds.
- Physical-board test handoff and user-returned result assessment:
  `fpga-hardware-validation`. The user programs and runs the board; wait for
  the required user result before advancing the cumulative stage.
- HDL module implementation:
  `hdl-module-implementation`, plus `fpga-systemverilog`, `fpga-vivado`, and
  `hdl-kernel-contract-gates`.
- Module verification:
  `hdl-module-verification`, plus `hdl-kernel-contract-gates`,
  `fpga-systemverilog`, and `fpga-vivado`.
- Module timing failure or retry tuning:
  `hdl-vivado-timing-closure`.
- Decoder-block, Layer FSM, Top FSM, token-loop, model FSM, or board-shell
  integration implementation:
  `hdl-integration-agent`, plus `fpga-systemverilog`, `fpga-vivado`, and
  `hdl-kernel-contract-gates`.
- Integration verification after an integration wave:
  `hdl-integration-verification`, plus `fpga-systemverilog`, `fpga-vivado`,
  and `hdl-vivado-timing-closure`.
- Hardware-specific board wrapper, external-memory flow, or board-level
  signoff:
  the matching hardware profile skill, such as `zcu104-xczu7ev-hardware`,
  plus `hdl-board-wrapper-signoff`, `fpga-systemverilog`, `fpga-vivado`, and
  `hdl-vivado-timing-closure`.
- Target-scale accelerator artifact generation:
  derive the required children and dependency order from the approved
  `module_mapping.json`, accepted `bringup.json`, and frozen stage contracts.
  Route missing implementations to `hdl-module-implementation`, then require
  `hdl-module-verification` before `hdl-integration-agent` consumes them.
  Require `hdl-integration-verification` for the composed target scope before
  board-wrapper/signoff work. A fixture or control scaffold is not evidence of
  target-scale arithmetic. Do not repeatedly route an insufficient artifact
  or relabel its coverage to obtain signoff.
  Model family, layer count, quantization format, module set, and iteration
  structure come from the approved design, not a previous model's workflow.
  Apply full-model requirements only to full-model claims; an approved partial
  bring-up stage needs evidence for its own declared scope and hardware gate.
- Reusable failure lesson capture:
  `skill-creator`.

## Role Skill Bootstrap

Before dispatching a wave, resolve every role named in its routing packet to a
validated project Skill under `skills/<skill>/SKILL.md`. If a required role
Skill is absent, stop that dispatch, use `skill-creator` to create its baseline
from the closest project or legacy reference, validate it, sync it to
`~/.codex/skills/`, and then rebuild the packet. Do not improvise an unnamed
role contract inside a worker prompt.

During generation, sub-agents may return a `skill_update_candidate` when a
failure pattern or successful recovery is reusable. The parent reviews that
candidate, updates the repository Skill first, validates and syncs it, and only
then retries the affected wave. Generated evidence may refine a Skill; it must
not silently redefine role ownership or weaken an existing gate.

## High-Level Workflow

For model-based requests, the mandatory planning entry sequence is model code
and config plus execution scope → parent-reviewed `model_graph.json` → mandatory
`module_mapping.json` → explicit user mapping approval → pre-generation approval
gate → referencing `bringup.json` generation/review → stage contracts → dispatch. Read
`docs/model_graph_bringup.md` and route graph extraction to
`parent-module-decomposition`, then stage planning to `fpga-incremental-bringup`.
Missing or unresolved graph semantics block affected packets. Run the separate
planning reference gate documented there before contract freeze, dispatch and
promotion, in addition to `design_contracts.py`. It is not invoked by the contract
CLI. Missing mapping files, failed references or blocked stage coverage prevent
affected dispatch. Pass graph/mapping/bringup identities and stage coverage to
independent verification as well as implementation; never copy the mapping into
the bring-up plan. Parent review of meaning, numerical evidence and prior user
checkpoints remains required even when both structural gates pass.
After presenting the concrete mapping and its identity, pause in
`awaiting_user_mapping_approval` until the user approves it. Parent review,
earlier input confirmation and blanket generation requests do not replace this
decision. Record the actual request/response in `module_mapping_approval.json`
bound to the mapping hash; send its path/hash to every affected worker. Require
`--expected-approval-sha256` in planning consumption checks, including standalone
operators. Before approval, do not generate `bringup.json` (including drafts),
freeze implementation contracts or dispatch implementation. After approval,
require `check_planning.py --before-bringup` to pass before authoring the plan;
bind its separate `module_mapping_approval` reference to the checked approval.
If the mapping changes, obtain fresh user confirmation. The
checker validates a recorded declaration, not human identity; actual user
rejection/revocation always overrides an earlier approval record.
The numbered implementation steps below run inside the accepted stage scope;
they do not authorize implementing all dependent stages before user checkpoints.

1. Parent interprets model, optimization/pruning, hardware spec, and design
   methodology.
2. Parent asks clarification questions before dispatch when methodology is too
   ambiguous to define module boundaries, interfaces, budgets, or verification.
3. Parent creates a recursive contract tree and assigns root HDL packets with
   interface contracts, memory residency contracts, verification contracts,
   resource measurement requirements, and allowed tuning knobs.
4. HDL module Sub-agents implement independent root packets or split them into
   child contract manifests with explicit child interfaces, ownership, tests,
   evidence paths, and remaining recursion depth.
5. Initial RTL is correctness-first and does not enforce final board resource
   ceilings. Real datapath modules pass module-level OOC synthesis to measure
   LUT/DSP/BRAM/URAM/timing before any resource-reduction pass.
6. Resource reduction cites measured utilization or timing bottlenecks and
   preserves passed correctness and memory-residency contracts. Final board
   ceilings are enforced only in the configured `resource_ceiling_phase`.
7. Module verification sub-agents audit each module wave.
8. Integration sub-agents compose only verified/tuned children.
9. Integration verification sub-agents audit the integration wave and run or
   inspect integration-level Vivado synthesis.
10. Before target-scale integration or a retry of a fixture-scoped board build,
   compare available evidence with the current stage's required modules,
   workloads, shapes, and numerical formats. Select ready implementation
   packets using the approved mapping and bring-up dependencies; do not assume
   a fixed projection/nonlinear/transport trio or a fixed layer count.
11. Queue target-scale integration only after every required child has passed
   verification for its assigned role, configuration, and coverage. Real
   datapaths require non-fixture evidence. Missing or stale child evidence
   blocks dependent integration rather than being replaced with a stand-in.
12. Before board-wrapper work, require independent integration evidence tied
   to the exact sources and the coverage defined by the frozen stage contract.
   A full-model claim must cover the approved graph, mapping, supported
   workloads, and numerical policy; partial-stage evidence must retain its
   exclusions and later dependencies. Use the project's applicable report
   format, not model-specific field names or self-declared flags as proof.
   Board-level signoff remains a separate gate requiring actual board-build
   evidence; integration approval does not grant it in advance.
13. Board wrapper and signoff sub-agents add the target hardware wrapper,
   interconnect, external-memory, clock/reset, constraint, and routed evidence
   only after integration evidence for the declared stage is sufficient.
14. If a sub-agent fails and the lesson is reusable, preserve evidence and
    update the relevant skill before retrying.

## Parent Feedback Loop

The framework is parent-centered:

1. User input enters the parent once.
2. The parent creates module packets and dispatch waves.
3. The parent emits `feedback_packet.json` for ready or failed sub-agents.
4. Sub-agents implement, verify, synthesize, audit, or recursively decompose
   within their assigned scope and return `subagent_result.json`,
   `child_contract_manifest.json`, or the required target evidence.
5. The parent refreshes `parent_loop_state.json` and `retry_plan.json`.
6. On reusable failure, the parent updates the relevant Skill, syncs runtime
   skills, and then retries the responsible sub-agent.
7. On pass, the parent advances to the next sub-agent wave.

The parent reads the actual worker results and updates the state records below.
Record missing tools, blocked dependencies, failed waves, evidence paths and the
next responsible owner. If a required agent capability or tool is unavailable,
mark the affected work blocked instead of inventing a runner command or claiming
completion. State records are agent-produced artifacts, not automatic runner outputs.

Required parent-owned loop artifacts:

- `parent_loop_state.json`: global status and next parent action.
- `feedback_packet.json`: scoped feedback sent to ready or failed sub-agents.
- `retry_plan.json`: retry gates, blocked waves, and parent action required
  before another sub-agent attempt.
- `hdl_subagent_spawn_ledger.json`: external sub-agent id and evidence
  bookkeeping.

## Evidence Identity

Hardware spec changes invalidate evidence. If FPGA part, target clock, device
resource inventory, budgets, memory data width, or allowed tuning knobs change,
regenerate planning artifacts and require fresh module OOC synthesis,
integration synthesis, and board evidence.

## Project Skill Location

Project-owned skill baselines live under `skills/`. The active Codex runtime
discovers installed skills from `~/.codex/skills/`; sync validated repository
skills there when future agent runs should use the new behavior.

When a reusable failure requires a Skill update, edit the repository copy under
`skills/<skill>/SKILL.md` first, then run:

```bash
python3 scripts/sync_project_skills.py sync --skill <skill>
python3 scripts/sync_project_skills.py check --skill <skill>
```

Do not make `~/.codex/skills/<skill>/SKILL.md` the only edited copy; it is the
runtime install location, not the project source of truth.
