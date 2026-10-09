# ISA-driven quantizer integration validation

The standalone arithmetic child is now connected through an ISA executor and the
existing native controller/bank templates. Public top compute control is the
PS-preloaded command BRAM path, not a direct quantizer command bypass.

Opcode3 `QUANTIZE(src_bank, data_bank, scale_bank, element_count)` acquires one
read role and two write roles atomically before engine command acceptance. It
reads exact FP32 elements, invokes the unchanged verified child, writes packed
INT4 data and separate BF16 scale, and only then returns matched completion.
The controller retires saved identity only after all role-specific releases are
accepted. Raw addresses/offsets are DMA-only; compute commands must set them zero.

[Final evidence](isa_try004/manifest.json) and [result](isa_try004/result.json):
29 input rows and 43 XSIM cases PASS with strict lint, generation reproduction,
contract identity, current source hashes and all stage exit codes zero. The test
program is commandBRAM `MM2S → QUANTIZE → S2MM(data) → S2MM(scale) → END`, using
real native XPM banks and testbench DMA bus-functional peers. It compares exact
Fraction-oracle INT4 data, BF16 scales, packing, tailpadding and role acquisition,
completion/write ordering, release and terminal behavior.

Coverage includes count1/13/32/33/256, zero/fractional/scaled/random/NaN inputs,
poisoned unused FP32 lanes, source/data/scale stalls, invalid alias/count/address/
opcode, full4bit DMA tags4/15, reset during input/output, and uninterrupted
same-bank two-row reuse with different scales and one final END.

Fresh OOC at 5ns, Vivado2025.2, xczu7ev-ffvc1156-2-e: LUT1915, FF1343,
RAMB36=6, RAMB18=1, URAM/DSP0. Synthesized unplaced WNS1.631ns/WHS0.079ns/
WPWS1.958ns; failing endpoints zero. External max setup delays are0.5ns;
external boundary hold is excluded. No routed timing or physical board claim.
Lint uses memory-interface stubs with stub-local diagnostics suppressed; real
XPM memories are exercised in XSIM and synthesized in the OOC hierarchy.

The generated controller applies the [approved configuration addendum](../modules/attention_quantizer_isa_generation_addendum.json): six tag-index width casts
per DMA engine in its local copy, preserving all full-width tag range checks.
Shared infrastructure and the verified quantizer child are unchanged. The
[scoped gate](../scripts/check_quantizer_isa.py) checks this standalone operator;
it does not claim the repository's full-model design validation.

Earlier failed trial packets are preserved. Trial1/2 exposed XSIM force/release
fixture behavior; the test now restores ready only when the real router confirms
legal acceptance. Trial3 had an insufficient fixed300cycle wait for the256element
error drain; the final bounded budget is elements*4+100, with all drain assertions
retained. No DUT arithmetic or protocol change was needed for these fixture fixes.

Full Q/K/V/output projections and Attention arithmetic RTL remain to be implemented
as ISA executors. This checkpoint proves ISA quantization, not full Attention,
vendor DataMover integration, pretrained-model quality or board execution.
