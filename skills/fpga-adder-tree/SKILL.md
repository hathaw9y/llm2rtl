---
name: fpga-adder-tree
description: Design, size, pipeline, and verify FPGA adder trees and reduction networks for quantized Transformer datapaths. Use when implementing dot-product reductions, partial-sum accumulation, balanced or segmented trees, LUT-versus-DSP reductions, carry-save structures, accumulator-width proofs, rounding/saturation, tail handling, valid alignment, fanout control, or timing closure of wide high-throughput reductions.
---

# FPGA Adder Tree

Treat reduction width, association, pipeline latency, and physical routing as one design contract.

## Workflow

1. Freeze operand widths, signedness, zero points, product format, maximum reduction length, output format, target clock, throughput, and backpressure behavior.
2. Compare a balanced registered tree, DSP cascade, segmented local trees plus a final accumulator, and a folded multi-cycle reduction when each is feasible.
3. Derive exact worst-case product and accumulator bounds. For signed `W_a x W_b` products, start from `W_a + W_b` bits and add reduction-growth bits, then check asymmetric two's-complement extrema explicitly.
4. Freeze the location of every rounding, truncation, saturation, requantization, and packed-lane extraction.
5. Pipeline to the target clock and align valid, mask, scale, tail, and backpressure metadata with every data stage.
6. Verify numerical behavior, short/tail reductions, flush/stall behavior, and timing/resource mapping.

## Required proof

Record product width, simultaneous terms, partial-sum widths, final width, association order, field guard bits, overflow policy, latency, initiation interval, and output-valid timing. Test all-minimum, all-maximum, alternating signs, cancellation, one-LSB-overflow, and every legal tail length.

## Physical-design gates

- Register high-fanout valid/reset/scale controls.
- Inspect SLR/clock-region crossings; logical balance does not guarantee physical balance.
- Compare LUT, DSP-cascade, and hybrid mapping with OOC synthesis.
- Reject an unpipelined level that misses the target clock or a pipeline that loses metadata alignment.
- Reject wraparound unless the algorithm contract explicitly requires modular arithmetic.

Use the separate DSP-packing skill for multiple arithmetic lanes within one DSP and the separate quantization skill for scale selection. This skill owns the reduction network and its numerical/timing proof.

## Output

Return the reduction equation, width derivation, candidate topology comparison, selected pipeline, cycle/II/resource estimate, RTL interface timing, directed tests, assertions, and synthesis/timing gates.
