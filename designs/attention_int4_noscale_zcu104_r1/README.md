# W4A4KV4 Attention with BF16 scales

This directory retains its original intake name. Current requirements include
BF16 scales, per-token Activation quantization, group-32 Weight quantization,
token/head KV quantization, INT32 integer dot accumulators, FP32 scaled group
combination, and BF16 Softmax probability storage. Q/K/V and output projections
are all in the Attention scope.

[Architecture](architecture.md) identifies the intermediate quantization
boundaries and native-bank metadata completion requirements.
[Numeric intake](intake.md) records the agreed requirements.

The explicitly requested intermediate quantizer is the first implemented child;
its frozen [module packet](modules/attention_int4_quantizer.json) defines exact
FP32-input to BF16-scale/symmetric INT4-output semantics. One command covers an
Activation token row, a KV token/head row or a Weight group of up to 32 values.
Detailed arithmetic choices: ties-to-even, symmetric codes [-7,7], FP32 input
subnormals treated as zero, nonzero scale clamped to BF16 minimum normal, and
zero-row scale 1.0. Outputs remain stable under backpressure; completion follows
the final accepted output. Its native-bank adapter must also finish data and scale
writes before authorizing bank release.

The [full Attention numerical reference](python/attention_reference.py) covers all
projections, QK scaling, masks, stable Softmax, BF16-probability PV and intermediate
requantization. It uses a mathematical FP32 exponential reference. This is not a
claim that the complete Attention RTL or hardware exponential is implemented.

```sh
python3 designs/attention_int4_noscale_zcu104_r1/python/test_attention_reference.py
```

The five numerical tests cover unequal group scales and tails, query selection,
causality, all-masked rows, equal-logit normalization, and shape rejection. They
exercise the full agreed numerical boundary chain; they do not establish
pretrained-model quality, hardware KV persistence, RoPE or physical-board results.

## Intermediate quantizer evidence

[Quantizer validation](evidence/quantizer_validation.md): 341 XSIM cases pass,
strict lint passes and fresh OOC synthesis uses LUT600/FF295/BRAM18 1/DSP0.
These are standalone-child results and unplaced timing estimates.

```sh
python3 designs/attention_int4_noscale_zcu104_r1/scripts/run_quantizer.py --mode all --out /tmp/attention-quantizer-new-evidence
```

Use a fresh output directory. [RTL](rtl/attention_int4_quantizer.sv) streams FP32
values after command acceptance and emits one INT4 nibble per value with shared
BF16 scale and a final-element marker. The response follows acceptance of the
last element; all output fields remain stable while ready is low.

## ISA execution

[ISA record](isa_spec.json) and [bank layout](bank_layout.json) describe opcode3
`QUANTIZE` with three logical bank operands and an element-count immediate.
[ISA top](rtl/attention_quantizer_isa_top.sv) connects commandBRAM, generated
controller, executor and three native XPM banks. Compute has no direct top-level
command bypass; PS supplies explicit load/quantize/store/END instructions.

[ISA validation](evidence/quantizer_isa_validation.md): 29 rows/43 XSIM cases,
strict lint, generated source reproduction and fresh whole-top OOC pass.

```sh
python3 designs/attention_int4_noscale_zcu104_r1/scripts/check_quantizer_isa.py --require-rtl
python3 designs/attention_int4_noscale_zcu104_r1/scripts/run_quantizer_isa.py --mode all --out /tmp/attention-isa-new-evidence
```

This is a scoped standalone ISA operator checkpoint. It does not implement all
Attention arithmetic or claim vendor DataMover/physical board validation.
