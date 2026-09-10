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

The Block Design is also the system-composition boundary. Model Scheduler,
DataMover Engine, vendor AXI DataMover, local-memory adapters, compute engines, native-memory
routing glue, and BRAM/URAM generators are packaged as separate cells and are
connected by BD nets. A board overlay must not hide those roles inside one
monolithic custom IP. Small scalarization wrappers may adapt packed reusable
RTL ports to IP-XACT interfaces, but may not absorb a neighboring role.

## Stable infrastructure

- bundled `ip/infrastructure/datamover_engine/` RTL and interface contract
- MM2S/S2MM channels, command queues and returned status/tag checks
- MM2S/S2MM adapters and stream width converters
- bank read/write arbitration, BRAM/URAM banks, pipelines and FIFOs
- vendor AXI DataMover and board-specific interconnect/clock/reset integration,
  generated separately for the selected hardware (vendor IP is not bundled)

DDR-to-local and local-to-DDR designs must reuse this engine. The scheduler
owns transfer scheduling, bank validity and error recovery; the engine checks
descriptors/status and reports diagnostics. Compute kernels use local memory.

These blocks transport opaque bytes and use parameterized client counts and
stream widths. They do not interpret W2/A2/KV2 or model layer types.

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
Host runtime -> AXI4-Lite(M,N,K,A/W/O DDR bases)
                                      |
                                      v
                               model scheduler
                                  |-> DataMover Engine -> vendor AXI DataMover / DDR
                                  |-> adapters / local bank ownership
                                  |-> single-tile compute IP
                                  `-> job completion/error register
```

The PS owns only whole-job M/N/K and the three DDR base addresses. The
model-specific scheduler snapshots them on `start`, generates tile coordinates,
DDR commands, edge extents, bank indices, accumulation decisions, and the
compute/drain sequence. Local addressing, queue limits, bank geometry and reset
coordination follow the DataMover interface contract and the frozen design
contracts, not historical transfer-engine assumptions. Configuration changes
require a new contract revision and affected-boundary verification.
