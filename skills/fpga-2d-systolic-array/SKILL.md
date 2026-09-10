---
name: fpga-2d-systolic-array
description: Design, compare, and verify two-dimensional systolic-array architectures and dataflows for FPGA Transformer and attention workloads. Use when choosing array dimensions, output/weight-stationary modes, cooperative or chained arrays, dense/sparse data reuse, prefill-versus-decode mapping, attention fusion, tiling, PE utilization, or matrix-layout schedules for QKV, QK^T, probability-times-V, output projection, and FFN computation.
---

# FPGA 2D Systolic Array

Design the array around sustained target-workload utilization, not nominal peak TOPS.

## Workflow

1. Freeze every matrix shape, batch/context regime, precision, sparsity pattern, target part, clock, on-chip capacity, and sustained external bandwidth.
2. Separate encoder/prefill GEMM from batch-1 decode GEMV or skinny GEMM. Do not assume one square topology is efficient for both.
3. Compare at least:
   - one conventional output- or weight-stationary baseline;
   - one workload-specific alternative such as cooperative/chained arrays, partitioned modes, diagonal sparse flow, or transformable matrix/vector execution.
4. Calculate tile occupancy, fill/drain, K reduction, tail padding, output offload, mode change, transpose/reorder, Softmax barrier, and memory-transfer cycles.
5. Freeze physical layouts and production order for Q, K, V, scores, probabilities, heads, and FFN tensors. Prove every fused producer order matches its consumer.
6. Specify the array contract: dimensions, PE operation, accumulator width, stationary state, stream/bank interfaces, valid/backpressure, tails, drain, reset, and mode-switch boundary.
7. Verify bit accuracy and schedule behavior, then obtain OOC resource/timing evidence at the target clock. Require board-level signoff separately when deployability is requested.

## Required calculations

For an `R x C` output-stationary array on output tile `M_t x N_t`, calculate spatial occupancy as `min(R,M_t) * min(C,N_t) / (R*C)`. Extend the model with reduction cycles, fill/drain, tiles, tails, load/offload, and stalls. Use a dependency-aware cycle timeline for chained attention.

Calculate packed bytes for every live tile and duplicate buffer. Include scales, sparse metadata, masks, alignment, and any score/probability storage.

## Decision gates

- Reject a square array that is mostly idle in the dominant decode regime.
- Reject attention fusion without a complete-row or correct online-Softmax state proof.
- Reject cascades that introduce an unbudgeted transpose/reorder buffer.
- Reject sparse routing when decoder/merge/crossbar cost or reduced clock erases skipped MACs.
- Reject utilization claims that omit sequence, head, hidden, or FFN tails.

Label important statements as `paper-reported`, `derived`, `measured`, or `assumption`. Use the separate DSP-packing, adder-tree, Softmax, pruning, quantization, or nonlinear skill when that subproblem becomes the decision focus.

## Output

Return frozen assumptions, baseline, candidate comparison with evidence labels, chosen dataflow, cycle/capacity/bandwidth/resource estimates, tensor-layout schedule, interface contract, verification gates, and open risks.
