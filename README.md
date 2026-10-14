# llm2rtl

**English** | [한국어](README.ko.md)

A Parent Agent framework that lowers actual Python model execution into a
module-execution ISA and implements, independently verifies, and validates FPGA
executors on hardware, one module at a time.

## Getting started from GitHub

You need Git, Python 3.10 or later, and an authenticated Codex CLI. See the
[official CLI guide](https://developers.openai.com/codex/cli/) for installation
and authentication. Run the following commands in a terminal.

```bash
git clone https://github.com/hathaw9y/llm2rtl.git
cd llm2rtl
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Provide a model ID and a hardware specification file to generate the prompt and
start an interactive Codex session. This example assumes you have selected ZCU104.

```bash
python3 scripts/start_accelerator.py \
  --model HuggingFaceTB/SmolLM2-135M \
  --hardware config/hardware/zcu104.json
```

For another model, provide its Hugging Face model ID or a local checkpoint path.
For another board, provide its hardware specification file. The specification
can be a UTF-8 JSON or text file describing the board, FPGA part, clock, resources,
DDR capacity and addresses, AXI connections and widths, runtime, and tool versions.
Codex investigates missing information and discusses it with you.

The launcher locates the repository root from its own location, so it works
regardless of the checkout directory's name or location. Relative `--hardware`
paths are resolved against the repository root. Use an absolute path for a
specification outside the repository. Absolute paths are also recommended for
local checkpoints.

To inspect the generated prompt without starting Codex, run the following command.
This requires neither a Codex installation nor authentication.

```bash
python3 scripts/start_accelerator.py \
  --model HuggingFaceTB/SmolLM2-135M \
  --hardware config/hardware/zcu104.json \
  --render-only
```

Each prompt is saved as a new file under `build/prompt_runs/`, which is excluded
from Git. Templates are available in [English](prompts/model_hardware_accelerator.en.txt)
and [Korean](prompts/model_hardware_accelerator.ko.txt), with the same inputs and workflow.
The launcher uses English by default. Set `--language en` or `--language ko` to
choose the prompt and conversation language; hardware input data is preserved as supplied.
Use `--checkpoint-revision <commit>` to specify the model revision. If omitted,
Codex investigates and proposes an exact checkpoint commit.

The first session inspects the repository, investigates the model and hardware,
and proposes operation-to-ISA-to-executor mappings. Execution scope, quantization,
performance targets, and ISA and module boundaries are discussed with you before
HDL implementation begins. Previous designs' PASS results are not inherited by
new designs. Prompt generation uses only the Python standard library. Model
runtime libraries and FPGA tools are prepared separately for the selected model
and board during implementation and verification.

## Architecture

New designs inspect the 15 common RTL sources listed in
[sources.json](ip/infrastructure/sources.json) and [the infrastructure guide](ip/infrastructure/README.md).
These provide bank primitives, a compatibility controller, FIFO/pipeline utilities,
and reference MM2S/S2MM engines with their configuration package.
Use the active infrastructure as the default RTL reference and reuse matching capabilities first.
For DMA, inspect the active MM2S/S2MM engines' direct bank connections and internal FIFOs.
Record reuse/adaptation decisions and isolate model-specific changes in a new design revision for verification.
Previous generic components and authoring templates are archived compatibility inputs.

```text
PS software
  model command order · DDR residency tiling · error recovery decisions
        ↓
PS-writable command BRAM + terminal END command + START
        ↓
isa_command_dispatcher
        ├─ datamover_executor: DMA_LOAD / DMA_STORE
        ├─ gemm_executor: GEMM
        └─ subsequent compute executors
```

- Only `DMA_LOAD` and `DMA_STORE` accept DDR/AXI addresses.
- Compute commands accept validated logical local bank IDs, with no raw addresses
  or bank offsets.
- The dispatcher routes commands and returns responses; PS owns model scheduling.
- PS writes the complete command program into command BRAM before execution.
  There is no streaming ring queue or producer/consumer index.
- Define command acceptance, PC progression, bank acquisition, concurrent issue,
  completion and END rules in the selected design revision.
- New designs separate read/write owners and acquire/release/busy state per direction.
  Overlap requires the declared conflict policy and committed data availability.
  Previous single-exclusive JSON contracts and checkers remain compatibility scope.
- Command BRAM is separate from the data-bank namespace. Data bank `0` is a
  valid operand bank and can be acquired and released normally.
- GEMM owns computation tiling within local banks; PS owns DDR residency tiling.

PS publishes a program in this order: `instruction records ending in END → START`.
PS must not modify those records while PL is `BUSY`. Each new revision defines and
verifies its bank acquisition, response/drain, release and END conditions.

The command sequence for `C=A@B` is:

```text
DMA_LOAD  DDR_A → BANK_A
DMA_LOAD  DDR_B → BANK_B
GEMM      BANK_A, BANK_B → BANK_C
DMA_STORE BANK_C → DDR_C
```

## Minimal common contracts

The existing common contracts retain their family semantics. New designs declare
their own ISA, ownership and completion contracts without silently changing frozen model contracts.

```text
contracts/common/
├─ isa_command_contract.json
├─ local_bank_contract.json
├─ evidence_identity_contract.json
└─ engine_completion_contract.json
```

Model shapes, precision, bank counts, array dimensions, and verification criteria
belong in design-specific files. New revisions do not use the previous module
mapping approval, bringup stage, or contract index hierarchy.

## New revision workflow

```text
Identify the exact model revision and Transformers source
→ model_trace.json
→ Agent proposes model-specific opcodes and executors
→ Discuss module boundaries, sharing, and fusion with the user
→ Decide the ISA and bank layout based on that discussion
→ Record modules, connections, reuse, pipelines and allowed choices in the structural contract
→ Validate the Python ISA interpreter
→ Discuss one executor's operations, ports, bank access, numerics, and verification
→ Concretize its structural obligations and write the module contract and implementation mapping
→ Implement and independently verify the module
→ Integrate cumulatively and build for the board
→ User validates on the physical FPGA
→ Discuss the next executor before implementing it
```

Design files:

```text
designs/<revision>/
├─ model_trace.json
├─ isa_spec.json
├─ bank_layout.json
├─ structure_contract.json
├─ isa_validation.json
└─ modules/<module_id>.json
```

See the [ISA architecture](docs/isa_model_lowering.md),
[minimal model bring-up workflow](docs/model_graph_bringup.md), and
[model-specific ISA and executor workflow](docs/framework_workflow.md) for details.
These detailed documents are currently in Korean.
Derive a [structural contract](docs/structure_contract.md) from behavioral requirements.
The implementation Agent reads it to select modules, instances, ports, parameters and cycles.

## Checks

The existing check_common_contracts.py and check_isa_design.py validate the single-exclusive
compatibility contracts. Their PASS does not verify new directional ownership. Define and verify
the directional contract in the new revision.


```bash
python3 scripts/check_common_contracts.py
python3 scripts/check_isa_design.py --design-dir designs/<revision>
python3 scripts/infrastructure_sources.py --check
python3 -m unittest discover -s verification/framework -p 'test_*.py'
```

The checkers validate structure, paths, SHA-256 identities, and declaration
consistency. They do not prove numerical accuracy, RTL behavior, Vivado results,
or physical FPGA behavior.

## Parent and Child agents

The Parent owns the model trace, ISA, bank lifetimes, structural contract, opcode backlog, and the
contract for the module currently being implemented. Even after discussing the
module list at the ISA stage, the Parent proposes each executor's implementation
and verification criteria before implementation and records the user's decisions
in the structural and module contracts. Both Children receive the same structural
contract version, hash and applicable obligations. An implementation Child writes and self-verifies only its
assigned module. A separate verification Child independently audits its structure,
connections, behavior and evidence. The next executor does not begin until the user accepts the
cumulative board checkpoint.

## Key paths

| Path | Role |
|---|---|
| `contracts/common/` | Four shared invariants |
| `docs/` | ISA, numerics, memory, and board workflow documentation |
| `config/hardware/` | Hardware profiles |
| `ip/infrastructure/controller/cmd_dispatcher_template.sv` | Compatibility controller v4; inspect its constraints before adapting to the new ISA |
| `ip/infrastructure/contracts/ownership_template.json` | Reusable ownership core template for model-specific bank and owner roles |
| `ip/infrastructure/sources.json` | Paths, hashes, dependencies and build profiles for 15 common RTL sources |
| `ip/infrastructure/archive/pre_reference_integrated_20261012/` | Removed generic components and templates; exact-byte compatibility copies |
| `scripts/` | Minimal contract and ISA design checkers |
| `scripts/start_accelerator.py` | Generate a model/hardware prompt and start Codex |
| `prompts/` | Model and hardware task prompt templates |
| `verification/framework/` | Checker regression tests |

Historical contracts, implementations, builds, and evidence are preserved in
timestamped backups outside the active design tree. Their results are not
automatically inherited as evidence for a new revision.

Current common RTL and archived compatibility inputs have separate scopes. Existing
model revisions and frozen evidence are not automatically migrated.

Generated engines follow `contracts/common/engine_completion_contract.json`: receive and
process all required memory responses and accept final writes before emitting completion
to release ownership. Check cycle/interface behavior under the selected revision
rather than inheriting compatibility-controller ports.
