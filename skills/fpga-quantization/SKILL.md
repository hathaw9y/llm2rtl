---
name: fpga-quantization
description: Specify, compare, and verify quantization for FPGA Transformer and LLM accelerators. Use when selecting fixed, integer, integerized-float, row-wise, mixed-precision, or progressive formats; defining W/A/KV/nonlinear bit widths, scales, zero points, clipping, accumulators, requantization, metadata, and calibration; or proving numerical accuracy, DSP/memory savings, residency, and end-to-end quality across prefill and decode.
---

# FPGA Transformer Quantization

Define every tensor transition explicitly; labels such as W4A8 are not a sufficient hardware contract.

## Workflow

1. Inventory each weight, activation, KV tensor, probability, nonlinear intermediate, scale, and accumulator.
2. Record signedness, encoding, bit width, scale/zero point, granularity, clipping/calibration, product/accumulator format, rounding, saturation, and stored metadata.
3. Compare uniform, row-wise mixed precision, progressive fetch/recompute, and integerized-float alternatives relevant to the workload.
4. Derive worst-case product and accumulator ranges, including asymmetric minimum values and zero-point terms. Align partial sums to a proved common scale before addition.
5. Calculate packed bytes, alignment, scale/importance metadata, conversion logic, DSP packing, lane imbalance, and sustained-bandwidth/capacity impact.
6. Build a bit-exact software model of every boundary and compare layer-by-layer with the floating-point reference.
7. Validate end-to-end task quality and synthesize conversion/packing paths as well as MAC arrays.

## Accuracy and hardware gates

- Separate clipping, scale/coefficient, product, accumulation, requantization, and nonlinear approximation error.
- Test real calibration tensors plus extrema, rounding halfway cases, saturation, scale transitions, and tails.
- Treat precision as a memory-residency and bandwidth decision, especially during decode.
- Reject mixed precision whose metadata, separate PE groups, or workload imbalance removes the nominal gain.
- Reject progressive quantization without deterministic confidence, retry, and worst-case latency behavior.
- Reject saved-bit claims that omit scale/index storage or conversion overhead.

Use separate DSP-packing, pruning, Softmax, or LayerNorm/GELU skills when their mechanisms are the primary problem. This skill owns format semantics, scale flow, width/error proof, and model-quality evidence.

## Output

Return a tensor-format table, candidate comparison with evidence labels, equations for quantize/dequantize/requantize, accumulator proof, byte/resource/bandwidth model, calibration plan, bit-exact tests, end-to-end quality gates, and open risks.
