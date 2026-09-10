---
name: fpga-dsp-packing
description: Derive, implement, and verify low-precision arithmetic packing and cascade schemes for FPGA DSP blocks in Transformer accelerators. Use when placing multiple INT4/INT8 products or MACs in one DSP48, sharing packed operands, correcting signed subfields, setting guard bits and extraction slices, using DSP cascade paths, switching precision modes, or evaluating whether packing improves sustained throughput after FIFO, crossbar, correction, overflow, placement, and timing costs.
---

# FPGA DSP Packing

Treat packing as a bit-level proof against the exact target DSP primitive, not as a nominal multiplications-per-DSP claim.

## Workflow

1. Freeze the device/DSP generation, port and cascade widths, register configuration, operand precision/signedness, common-operand opportunities, accumulation length, target clock, and matrix schedule.
2. Compare direct multipliers, packed products, bit-split arithmetic, and cascade-based grouping using useful sustained MAC/s.
3. Draw the packed fields. Prove offsets, sign extension/correction, guard bits, product isolation, accumulated-field isolation, extraction, overflow adjustment, and rounding.
4. Count the feeding network: FIFO/reorder, operand broadcast, sparse selector, crossbar, cascade breaks, reduction nodes, PSUM merge, registers, and control.
5. Implement directed and random bit-exact tests before using the scheme in an array.
6. Confirm the intended primitive mode in synthesis and inspect post-route DSP placement, cascade use, congestion, and target-clock timing.

## Mandatory test cases

Exercise every sign combination, minimum negative, maximum positive, zero, random values, maximum safe reduction, one step past the safe bound, all tails, stalls, and precision-mode transitions. Compare unpacked lanes with independent full-width arithmetic before rounding.

## Rejection gates

- Reject copied offsets from a different DSP generation or operand format.
- Reject a scheme without an explicit correction for interior signed fields.
- Reject product-only guard-bit proofs that omit accumulated carries.
- Reject packing when reorder/correction/merge logic or reduced clock erases the lane gain.
- Reject mode changes without a quiescent drain boundary.

Use the separate adder-tree skill for wide reductions and the separate quantization skill for scale semantics. This skill owns DSP field packing, cascade mapping, and their proofs.

## Output

Return the primitive configuration, bit-field diagram, algebraic proof, maximum accumulation bound, feeding/extraction logic, sustained-throughput comparison, RTL timing contract, verification vectors, and synthesis/route gates.
