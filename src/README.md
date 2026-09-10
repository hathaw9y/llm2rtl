# Host framework

All model-facing commands must take an explicit `model_id` or model-manifest
path. The host framework must not discover a singleton model from
`config/models` or other global state. Per-model compiler and scheduler state
is rooted at `models/<model_id>/` and `orchestration/models/<model_id>/`.

Planned packages:

- `frontend`: checkpoint and model graph import
- `ir`: tensor, quantization, operation and memory-residency IR
- `scheduler`: command/microcode and lifetime generation
- `codegen`: HDL/IP configuration and Vivado manifest generation
- `verify`: golden vectors, evidence parsing and contract gates
