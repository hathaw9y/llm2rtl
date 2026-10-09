# Intermediate INT4 quantizer validation

Standalone `attention_int4_quantizer` implements one buffered FP32 input row,
exact BF16 RNE(absmax/7) scale and symmetric INT4 RNE output [-7,7]. Per-token
Activation, KV token/head or Weight group32 granularity is chosen by the caller.
Zero scale convention is 1.0, FP32 subnormal inputs are treated as zero, and
nonzero scale is clamped to BF16 minimum normal. NaN/Inf rows are fully consumed
and return error without output.

[Final source manifest](quantizer_final001/manifest.json) and
[tool result](quantizer_final001/result.json) match current source hashes.
XSIM passes 179 cases at max length13 and 162 cases at max length256, comparing
329 independent Fraction-oracle rows including extrema, ties, BF16 scale
rounding, group tails, all finite exponents, nonfinite rows, backpressure and
reset. Strict -Wall Verilator lint passes without waivers.

Vivado 2025.2 OOC synthesis on xczu7ev-ffvc1156-2-e at 5ns: LUT600, FF295,
RAMB18=1, DSP0. Unplaced estimates WNS2.240ns/WHS0.084ns/WPWS1.958ns;
TNS/THS/TPWS and failing endpoints are zero. HD.CLK_SRC and modeled external
setup delays are provided; external hold is excluded. No routed timing or
physical board validation is claimed.

[Full Attention reference](../python/attention_reference.py) passes five numerical
boundary tests. Complete Attention RTL, native-bank adapters, hardware KV cache
and pretrained-model quality are outside this completed quantizer checkpoint.
Quantizer completion follows the final accepted output, while its future bank
adapter must also finish both payload and scale writes before releasing banks.

[Checkpoint identities](quantizer_checkpoint.json) and independent review are
separate from previous model/infrastructure evidence, which is not inherited.
