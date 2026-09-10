---
name: fpga-softmax
description: Design and verify FPGA Softmax and fused attention normalization for Transformer workloads. Use when implementing stable multi-pass, tiled online, long-sequence fused, quantized, LUT/PWL, exp-log, base-2, or approximate Softmax; defining causal/padding masks, running max/sum/value state, replay buffers, reciprocal/division, row tails, numerical formats, approximation error, and producer-consumer scheduling between QK^T and probability-times-V.
---

# FPGA Softmax

Preserve stable row semantics first; treat every changed exponential base or function approximation as explicit model approximation.

## Workflow

1. Freeze the row axis/length, `1/sqrt(d_k)` scaling, masks, all-masked policy, input/output formats, error tolerance, tile order, target throughput, storage, device, and clock.
2. Use stable Softmax `exp(x_i-m) / sum_j exp(x_j-m)` as the reference, with `m = max_j x_j` after masking.
3. Compare stable multi-pass, tiled online/fused, quantized, and approximate implementations.
4. For tiled online Softmax, prove running-max rescaling of both the denominator and any fused weighted-V accumulator across every tile.
5. Count max reduction, exponential lanes, sum reduction, reciprocal/division, normalization/replay, masks, FIFOs, tails, and backpressure.
6. Define every LUT/PWL domain, coefficient format, segment lookup, clipping, underflow, rounding, and out-of-range behavior.
7. Validate probabilities, row sums, fused attention outputs, and end-to-end model quality before synthesis/timing comparison.

## Mandatory cases

Test equal logits, one dominant logit, maximum dynamic range, underflow-heavy rows, masked tails, causal boundaries, all-masked rows, length one, every tail length, running-maximum changes in each tile, LUT/PWL boundaries, rounding halfway cases, saturation, and reciprocal extremes.

## Rejection gates

- Reject independent per-tile normalization without global running state.
- Reject masks that participate incorrectly in the max or denominator.
- Reject an `N x N` buffer assumption without exact packed-byte capacity.
- Reject claimed overlap without a dependency timeline and bounded FIFO/backpressure proof.
- Reject radix-2/PWL/quantized accuracy based only on random function samples; require target-model validation.
- Reject fusion when the systolic producer cannot supply the required Q/K/V order.

Use separate systolic-array, quantization, adder-tree, or LayerNorm/GELU skills when those subproblems dominate. This skill owns Softmax semantics, online/fused state, approximation, and numerical/scheduling proof.

## Output

Return semantics and formats, candidate comparison with evidence labels, recurrence or pass schedule, storage/cycle/resource estimates, approximation/error analysis, interface/backpressure contract, directed tests, and synthesis/end-to-end quality gates.
