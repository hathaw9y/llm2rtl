# Architecture

## Multi-model organization

The framework has no implicit singleton model. `models/registry.json` lists
independent workspaces under `models/<model_id>/`. Each workspace owns its
imported model contract, graph, memory plan, variant selection, and per-hardware
target state. Reusable infrastructure and hash-identified compute variants are
shared through `ip/`, `ip_repo/`, and `config/ip_variants/`.

Board shells are also shared. A model target combines one model workspace with
one `config/hardware/<profile>.json` and one `boards/<board>/` shell; generated
outputs and evidence are isolated below
`build/models/<model_id>/<hardware_profile_id>/`.

Each concrete board overlay generates its Vivado Block Design as a remote-
managed source tree under `boards/<board>/<overlay>/bd/<bd_name>/`. The
`build/` tree contains the Vivado project, runs, reports, and deployable
artifacts; it is not the canonical location of the `.bd` or generated BD IP.

The Block Design connects PS, external-memory interfaces and vendor IP to the
selected accelerator under its declared interface and clock/reset contracts.

## Stable infrastructure and design inputs

- 14 common RTL sources identified by `ip/infrastructure/sources.json`
- reference MM2S/S2MM engines and their configuration package
- bank memory/arbiter/ownership/router primitives, a compatibility controller,
  pipelines and FIFOs; see `ip/infrastructure/README.md`
- vendor AXI DataMover and board-specific interconnect/clock/reset integration,
  generated separately for the selected hardware (vendor IP is not bundled)

Previous generic DMA components and authoring templates remain archived for frozen
references and explicit compatibility regressions. They are not default design inputs.
The active infrastructure is the default RTL reference. Reuse matching capabilities first,
record module-level reuse/adaptation decisions, and isolate model-specific changes in a new design revision.
Inspect the active MM2S/S2MM engines' direct bank interfaces, context FIFOs and completion behavior.
The compatibility controller and reference config_pkg defaults require explicit adaptation to the agreed ISA and bank plan. PS owns program order. Specify command
acceptance, completion, address units, payloads and concurrency in the selected revision.

New designs separate read/write bank ownership. A model-specific bank subsystem defines
owner state, engine ports, muxes, commit tracking and memory connections. One owner per
direction is allowed; read/write overlap requires a safe conflict policy and committed data.
Existing single-exclusive primitives and JSON contracts are compatibility inputs, not
complete directional implementations. See docs/framework_workflow.md section 1.5.

Each new design records a structural contract in `designs/<revision>/structure_contract.json`.
It links behavioral requirements to module boundaries, reuse decisions, concrete connections,
directional bank roles, multiport weight stripes, executor read pipelines and controller completion paths.
Implementation agents read that contract and map obligations to actual files, instances, ports,
parameters and cycles. Verification agents check the mapping against RTL and actual evidence.
See [structural contract guidance](structure_contract.md) for scope, examples and change rules.

## Model- or quantization-sensitive blocks

- projection GEMM/GEMV
- packed weight unpack and dequantization
- token-wise activation quantize/requantize with explicit scale metadata
- RMSNorm, RoPE, softmax, SwiGLU and KV-cache address generation
- model-specific scheduler loop and execution policy

Compute IP configuration is selected from contracts generated for a model.
Llama-specific operation order belongs in scheduler data, not in the memory
fabric.

## Control flow

```text
PS program -> command BRAM + START
                        |
                        v
                    controller
                       |-> DMA engine -> vendor DataMover / DDR
                       |-> per-operation *_engine -> local banks / compute core
                       `-> completion responses -> bank release -> specified END condition
```

New designs inspect the current common RTL and define acquisition, acceptance,
drain, response, release and END behavior in their own contracts. Source identity,
compilation and historical fixture results do not establish those
properties for a new model.

Validate arithmetic, synthesis, timing, DDR and board behavior separately.
