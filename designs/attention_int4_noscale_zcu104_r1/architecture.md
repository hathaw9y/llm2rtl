# Attention construction with intermediate quantization

Confirmed scope: Q, K, V and output weight projections plus scaled dot-product
Attention, using W4A4KV4 storage and BF16 scale metadata. A standalone operator
will expose shape parameters; an exact pretrained model has not been specified.

```text
X4 + token scale
  → shared group-32 INT4 projection (INT32 partial sums, FP32 scaled group sum)
      ├─ Q FP32 → quantizer over each token row → Q4 + BF16 token scale
      ├─ K FP32 → quantizer per token/head → K4 + BF16 token/head scale
      └─ V FP32 → quantizer per token/head → V4 + BF16 token/head scale
  → QK: INT32 dot → FP32 apply Q/K scales and 1/sqrt(head_dim)
  → masks and stable Softmax → BF16 probability P
  → PV: BF16 P × dequantized INT4 V, FP32 accumulation
  → concatenate heads → per-token quantizer → context4 + BF16 token scale
  → group-32 output projection → FP32 result
  → per-token quantizer → output4 + BF16 token scale
```

One reusable quantizer serves these boundaries sequentially. Weight preprocessing
can invoke the same numeric policy for each output-row/input-group of 32, although
static weights can be prepared by software. Per-token Activation scales do not
replace independently stored Weight scales or KV token/head scales.

## Module boundaries

1. `attention_int4_quantizer`: buffered FP32 row → signed INT4 stream plus
   one BF16 scale. This module is the current explicitly requested implementation.
2. Grouped projection engine: reuse the same INT4 dot product datapath for Q/K/V
   and output projections; dequantize each partial sum before group combination.
3. Score/normalization/value engine: integer QK dot, scaled logits, masks,
   stable Softmax and FP32 PV accumulation with BF16 stored probabilities.
4. Local Attention sequencing and native-bank adapter: operate the verified
   children, quantizer and tensor/scale banks; report completed command identity.
5. Generated controller and bank wrapper: copy MM2S/S2MM templates, add these
   design-owned compute ports/roles and explicit Attention opcode operands.

Probabilities are BF16 under the agreed numeric policy; PV is therefore a mixed
BF16/INT4 boundary. It is not described as an INT4-only product or INT32-only
accumulation. Attention logits and group-combined intermediate sums are FP32.

## Completion and metadata

- A quantizer completion follows the final accepted quantized-data output.
- The bank adapter must accept every output data write and the BF16 scale write
  before treating that quantizer result as a usable downstream operand.
- The full Attention completion follows every required read response, every
  final output data write and final output scale write. Only then may the
  generated controller release the command's stored bank roles.
- No scale/data pair may become visible as a valid operand while only one half
  is committed. Read/write direction alone is not tensor-validity bookkeeping.

## Upcoming verification boundaries

Bit-exact quantizer tests first. Then unequal group scales and INT32 projection
bounds, Q/KV scale addressing, stable masked Softmax, BF16-probability PV and all
intermediate requantizations. Compose only verified children. Run fresh whole
Attention comparisons and generated native-bank/controller completion tests.
Separate simulator/OOC proof from routed hardware or pretrained-model quality.

## ISA execution boundary

Compute modules are children of ISA executors. The intermediate quantizer is
being connected through the native controller's opcode3 `QUANTIZE` extension:
operand0 is FP32source, operand1 is INT4destination, operand2 is BF16scaledestination.
Count is an opcode-specific element immediate; external/local raw addresses are
DMA-only. Allthree operands are acquired atomically before compute commandvalid.
See [ISA record](isa_spec.json), [bank layout](bank_layout.json), and the
[frozen integration packet](modules/attention_quantizer_isa.json).

The executable test program is commandBRAM `MM2S → QUANTIZE → S2MM(data) →
S2MM(scale) → END`. Numerical projection/Attention reference functions are golden
models; they do not replace PL arithmetic with host-side tensor computation.
