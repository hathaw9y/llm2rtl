# Kernel variant contract compiler

`variant_contract.py` is the pre-RTL gate for model- and numeric-sensitive IP.
It reads a declarative variant, applies universal native-memory rules, dispatches
to an operation validator, and derives ports, Router instances, packing,
storage, address formulas, arithmetic bounds, and Scheduler responsibilities.

Standalone regression only (not a design-bound generation gate):

```bash
python3 src/codegen/variant_contract.py \
  verification/framework/fixtures/projection_gemm_ws32_w4a4_acc16.json \
  --fixture-only \
  --hardware-config config/hardware/zcu104.json \
  --output artifacts/projection_gemm_ws32_w4a4_acc16.derived.json
```

RTL generation must not start when `valid` is false. A matching canonical
SHA-256 identifies a reusable variant; changing model format, tile shape,
packing, accumulation, memory width, or target creates a different identity.

The base checks apply to every IP. Operation-specific checks are plugins in the
compiler. GEMM is the first plugin; convolution, normalization, softmax, RoPE,
and other kernels must add their semantic rules before they can be generated.

The compiler deliberately does not generate RTL. It generates the complete,
reviewable contract that an RTL implementation agent, golden-model generator,
test generator, Scheduler generator, and Vivado flow must all consume.

For design-bound use, first initialize, fill and freeze contracts using
`scripts/design_contracts.py`; see `contracts/README.md`. Put the exact variant
inline in the selected module contract's `variant` field before freezing:

```sh
python3 src/codegen/variant_contract.py --contract-index contracts/designs/demo/r01/contract_index.json --expected-sha256 PARENT_SHA256 --module gemm
```

The CLI consumes the frozen module variant and hardware after validating the
whole bundle; standalone spec/model/hardware overrides are rejected in this mode.
The Python `compile_variant` function remains a pure low-level validator for
unit tests, not a substitute for the CLI's design gate.

Pass your own model input JSON through `--model-config` to make model/variant
weight and activation bitwidth mismatches a hard error. Model selection is
explicit; code generation must never infer one global model from the repository.
No generated model workspace is bundled. The fixture is a legacy regression
input, not a recommended numeric format or an implemented accelerator.
