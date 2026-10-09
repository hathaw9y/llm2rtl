# INT4 group128 candidate quality probe

The original Qwen/Qwen2.5-0.5B checkpoint at revision
`060db6499f32faf8b98477b0a26969ef7d8b9987` was independently loaded with
Transformers. No previous build, design, or generated model was used.

`int4.py` defines reusable quantization, dequantization, nibble packing and
unpacking semantics. `probe.py` reproduces `quality_probe.json` from that
local checkpoint. It never writes a packed full model. JSON includes
checkpoint and tokenizer SHA-256 pins, weight-by-weight errors and the exact
quality probe texts/token IDs. Embedding and LM head retain the same tied
Parameter; quantization occurs once for the shared storage.

| Tensor | Candidate format | Probe treatment |
| --- | --- | --- |
| Linear and shared embedding/head weights | Symmetric signed INT4 [-7,7] | Quantize from BF16 checkpoint, reconstruct BF16 |
| Per-row K-group128 scales | BF16, positive | Computed from row-group max(abs(w))/7, rounded to BF16 before quantization |
| Norm weights and biases | BF16 | Original values |
| Activations and KV | BF16 proposed | Transformers reference behavior; no independent bit-exact hardware proof |
| Attention probability, nonlinear intermediates | Not frozen | Transformers eager implementation |
| MAC accumulation | FP32 proposed | CPU library reference, no fixed pipeline/rounding proof |

Rounding is ties-to-even. Even K occupies the low nibble and odd K the high
nibble. An odd-K row ends in a zero padding nibble. Code -8 is reserved.
All-zero groups store scale 1. BF16-scale underflow also falls back to 1;
the checkpoint probe does not establish this as a useful subnormal policy.
Dequantization is BF16(q * FP32(stored scale)). Finite symmetric codes give
`abs(q*s) <= 7*s`; a K-term dot-product has real bound
`sum_k 7*s_group(k)*abs(a_k)`. A fixed-point accumulator-width proof requires
the activation range and scale alignment to be specified separately.

169 distinct weight matrices contain 493,961,216 values. Packed INT4 storage
is 246,980,608 bytes and scale storage is 7,718,144 bytes: **242.90 MiB** in
total, excluding norms/biases, alignment, activations, KV and DDR descriptors.
No residency, bandwidth, DSP savings or hardware timing claim follows from
this count.

| Fixed short probe | Tokens | BF16 perplexity | INT4 reconstructed perplexity | NLL increase |
| --- | ---: | ---: | ---: | ---: |
| Computing | 42 | 18.84 | 34.64 | 0.609 |
| Attention | 43 | 49.59 | 77.27 | 0.444 |
| Korean | 62 | 9.75 | 20.08 | 0.722 |

These probes show material quality drift from naive max-absolute group128
quantization. They are not a representative dataset and have no chosen
acceptance threshold. Aggregate weight RMSE is 0.0024633, MAE is 0.0019984,
and maximum absolute error is 0.1181641. JSON separates BF16 reconstruction
rounding, stored-scale/code changes and excess above the stored-scale range;
these components are diagnostic comparisons and do not add orthogonally.

Packing roundtrips, every signed code, zero groups, odd K and group tails,
ties-to-even halfway rounding, reserved-code rejection and padding rejection
passed. These are software format tests only. Calibration/AWQ/GPTQ and
representative multilingual/domain benchmarks are outstanding. The format
can inform an ISA reference, but this probe does not promote model accuracy
or hardware implementation to PASS.

Reproduce:

```sh
/home/eunji/anaconda3/envs/PTP/bin/python designs/qwen25_05b_zcu104_r1/quantization/probe.py
```
