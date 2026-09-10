---
name: fpga-layernorm-gelu
description: Design and verify FPGA LayerNorm, GELU, and shared nonlinear vector engines for Transformer inference. Use when choosing two-pass, sum/sum-of-squares, Welford, look-ahead, LUT, piecewise-linear/polynomial, or programmable-vector implementations; sizing nonlinear precision and buffers; scheduling LayerNorm or GELU between matrix stages; rate-matching reductions; or validating inverse-square-root, approximation error, tails, and numerical stability.
---

# FPGA LayerNorm and GELU

Design nonlinear kernels as blocking numerical pipelines with explicit accuracy and replay contracts.

## Workflow

1. Freeze the normalized axis/vector length, GELU domain, input/output formats, epsilon, gamma/beta formats, throughput target, producer/consumer order, buffering, device, and clock.
2. For LayerNorm, compare two-pass squared deviation, one-pass sum/sum-of-squares, Welford, and segmented/look-ahead reduction. State how the input vector is replayed or buffered.
3. For GELU, compare dedicated LUT/PWL/polynomial logic, a shared vector engine, and mixed-precision reuse. Define clipping and out-of-domain behavior.
4. Derive every accumulator/intermediate width and every rounding, saturation, reciprocal, and inverse-square-root step.
5. Rate-match the nonlinear path with neighboring matrix engines. Count stalls, buffer pressure, mode switches, and layout/precision conversion.
6. Validate with calibration tensors and adversarial vectors, then synthesize each credible candidate at the target clock.

## Numerical gates

- Treat `variance = E[x^2] - E[x]^2` as cancellation-sensitive. Compare it with Welford or a two-pass reference over the actual fixed-point range.
- Clamp a small negative variance only under a documented numerical policy; never use clamping to hide overflow or width errors.
- Test constant and near-constant large-offset vectors, maximum variance, vector length one, tails, gamma/beta extrema, LUT/PWL boundaries, and out-of-range GELU inputs.
- Report maximum/mean error, row statistics, and end-to-end model quality. A small function error alone is insufficient.

## Scheduling gates

- Reject a design that assumes LayerNorm is hidden without a dependency timeline.
- Reject FFN1-GELU-FFN2 streaming without compatible order and bounded backpressure.
- Reject a shared vector engine whose mode/conversion cost causes matrix-engine stalls beyond the dedicated-unit baseline.
- Reject an approximation without coefficient formats, segment lookup cost, and complete-domain behavior.

Use the separate adder-tree skill when the reduction network becomes the focus and the quantization skill when selecting scales/bit widths. This skill owns nonlinear arithmetic, buffering, rate matching, and accuracy evidence.

## Output

Return the equations/formats, candidate comparison with evidence labels, selected pipeline, buffer/replay schedule, width/error analysis, cycle/II/resource estimate, interface timing, directed tests, and synthesis/timing gates.
