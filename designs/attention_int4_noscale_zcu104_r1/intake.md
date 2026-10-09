# W4A4KV4 Attention with BF16 scales — intake

Status: full projection scope and proposed KV/BF16-probability/FP32-group rules accepted by user. Intermediate quantizer implementation is in progress.
Directory name retains the original intake label only. The requested design now
has BF16 quantization scales. The intermediate quantizer module contract is frozen; the complete Attention
implementation contract is still being developed and no implementation PASS is claimed.
Existing model revisions and infrastructure evidence remain unchanged.

## Confirmed user decisions

- W4A4KV4 storage with BF16 scale metadata.
- Activation quantization is per-token.
- Weight quantization uses groups of 32 elements.
- Integer products use wider INT32 or INT16 accumulators; initial proposal INT32.
- Preserve attention factor 1/sqrt(head_dim) and Softmax normalization.
- Use the native controller/bank ownership/routing/memory completion approach.

## Proposed concrete numeric boundaries

Projection scope and KV/probability/group-combination precision are confirmed. Detailed rounding/FTZ conventions below are the implementation choices recorded in the quantizer module packet.

- Signed two's-complement INT4 storage; explicitly round and saturate each
  requantization boundary. Symmetric zero-point 0; BF16 positive scales.
- Projection weight shape [output_features, input_features]; each output row
  has an independent BF16 scale for every contiguous group of 32 input features.
  Tail groups are masked, not interpreted as additional valid operands.
- Activation scale is per token over the activation feature row. Separate
  tensors (input, Q, projection inputs/output) have independent scale metadata.
- For one projection output: group_sum[g] = sum(a4[k]*w4[o,k]) in INT32;
  real_output = sum_g(group_sum[g]*a_scale[token]*w_scale[o,g]).
  Proposal: scale products and group combination use FP32, then output is
  quantized per token with BF16 scale. Different weight scales must never be
  factored out of the whole integer dot product as a single common scale.
- KV scale granularity proposal: independent BF16 scale for each token and
  each KV head, over that head's feature vector. K and V have separate scales.
- QK score: INT32 dot, multiply Q and K scales, then apply 1/sqrt(head_dim).
  Score accumulation is not forced into INT4 storage.
- Softmax uses stable max-subtracted row semantics with causal/padding masks.
  Proposal: FP32 internal arithmetic and BF16 stored probabilities; P4 is a
  separate option requiring an explicit probability quantization boundary.
- Attention P*V and output projection conversion depend on the confirmed
  probability precision. A BF16 probability input must not be described as an
  INT4*INT4 MAC without explicitly converting it to INT4 first.
- All-masked rows return zero; BF16 scales must be finite and positive for
  nonzero tensors. Zero-tensor scale convention, rounding mode and clipping
  are to be frozen in the implementation packet.

## Confirmed scope and remaining architecture

1. Include Q/K/V and output projection weights.
2. KV token/head scale granularity, BF16 probabilities and FP32 group combination are confirmed.
3. Parameterized operator dimensions/workload will be proposed next. No exact
   pretrained model, RoPE convention or model accuracy requirement is supplied.

## Independent range proof

Signed INT4 x is in [-8,7]. Products lie in [-56,64]. A group of 32 exact
products lies in [-1792,2048], requiring at least 13 signed accumulator bits.
INT16 is safe for this individual group. INT32 is proposed consistently for
projections and QK; longer unreduced dot products require separate range proofs.
For QK length D the exact sum lies in [-56D,64D]. INT16 covers the worst positive
bound only for D <= 511. INT32 covers D <= 33554431 at this raw INT4 boundary.
Scaled/group-combined arithmetic has a distinct floating-point range contract.

## Infrastructure and verification

- A packed 128-bit word carries 32 INT4 elements or 8 BF16 scales. Payload,
  metadata layouts, scale addressing, and bank ownership must be defined together.
- Generated compute ports and role IDs belong to the design revision. Shared
  named roles remain MM2S/S2MM only.
- Acquire every required operand/data/scale bank before engine command acceptance.
- Engine receives/processes every required memory resp_valid and accepts the
  final output and scale writes before emitting completion. No request for the
  completed command follows completion; release waits matching-role acceptance.
- Bit-exact reference and test vectors must use decoded BF16 scale values and
  the exact rounding/saturation boundaries implemented in RTL.
- Tests include group tails, unequal scales between groups/tokens/heads, extrema,
  zero tensors, causal/padding/all-masked cases, response latency, final writes,
  completion/release order, and no scale-metadata/payload mismatch.
- Fresh simulation/lint/OOC evidence is required. No board or model-quality
  claims follow from illustrative operator vectors alone.
