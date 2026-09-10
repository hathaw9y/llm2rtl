---
name: fpga-pruning
description: Select, map, and verify FPGA-friendly Transformer pruning and sparse execution schemes. Use when evaluating balanced block, column-balanced, fixed-length token, cascaded token/head, cross-stage prediction, or dynamic token sparsity; designing sparse formats, top-k/selection, lane balancing, compacted-token mappings, metadata, and sparse schedules; or deciding whether skipped computation and memory exceed padding, index, routing, merge, accuracy, and clock costs.
---

# FPGA Transformer Pruning

Translate algorithmic sparsity into measured end-to-end savings with a complete sparse-data contract.

## Workflow

1. Freeze what is pruned: weights, blocks, tokens, heads, attention pairs, or precision. Record selection time, target density, retraining/calibration, quality budget, and prefill/decode regime.
2. Select the closest pruning class and compare the dense baseline with at least one structured/balanced and one more adaptive alternative when model accuracy permits.
3. Calculate value, index, pointer, bitmask, header, padding, alignment, scale, and duplicate-buffer bytes.
4. Model selector/sorter/decoder/merge cycles, lane imbalance, burst efficiency, useful MACs/cycle, and post-route clock.
5. Define sparse format, block shape, index width, end markers, ordering, top-k ties, all-pruned behavior, token/head identity mapping, and causal/positional semantics.
6. Verify sparse execution against dense masked computation, then measure end-to-end latency, bandwidth, energy, and model quality.

## Decision rules

- Prefer balanced block formats when deterministic lane occupancy and compact indices matter.
- Prefer fixed-length token targets when variable shapes create more padding and bubbles than adaptivity saves.
- Use cascaded token/head pruning only with persistent compact-to-logical mappings across layers.
- Use cross-stage prediction only when predictor cost is amortized or its estimate is reused.
- Distinguish weight sparsity from attention/KV-cache work. Weight pruning does not remove dense attention arithmetic.
- Treat prefill as potentially compute-bound and decode as potentially weight/KV-bandwidth-bound; calculate both separately.

Sparse storage wins only if `values + metadata + padding < dense bytes`. Sparse execution wins only if skipped work/traffic exceeds selection, routing, merge, conversion, imbalance, and reduced-clock costs.

## Evidence gates

- Freeze dense and pruned checkpoints and report task quality for both.
- Test empty/full blocks, index limits, invalid/duplicate indices, tails, ties, all-pruned cases, and backpressure.
- Measure effective density, metadata ratio, lane occupancy, sustained bandwidth, and achieved clock.
- Reject kernel-only speedups that do not improve the complete inference path.

Use separate DSP-packing, systolic-array, quantization, or Softmax skills when those mechanisms become the primary design problem. This skill owns pruning policy, sparse representation, schedule, and cost/quality proof.

## Output

Return pruning semantics, candidate comparison with evidence labels, sparse-format contract, memory/compute/control cost model, selected architecture, accuracy requirements, directed tests, and end-to-end evidence gates.
