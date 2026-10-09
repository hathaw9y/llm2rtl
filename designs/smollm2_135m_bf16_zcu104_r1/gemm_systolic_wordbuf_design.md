# Word-buffered 16x16 BF16 systolic GEMM

The GEMM ISA command, BF16 arithmetic, K ordering, 16x16 PE array, bank
roles, and completion contract match `gemm_systolic_executor`. This variant
stores each returned 128-bit bank word unchanged. At wavefront injection it
selects the required BF16 lane from at most three words per row. This removes
the 16x16 BF16 per-lane write demultiplexers in the previous input tile buffer.

| Standalone post-synthesis measure | Original | Word-buffered |
| --- | ---: | ---: |
| LUT | 190,018 | 137,660 |
| FF | 38,206 | 42,327 |
| DSP | 263 | 263 |
| Setup WNS at 5 ns | +0.479 ns | +0.734 ns |

The LUT change is -52,358 (-27.6%), while the FF change is +4,121. The
standalone XSIM tests exercise all existing GEMM cases, including a complete
M32/N192/K576 command, and compare 528 selected layer-0 q_proj checkpoint
outputs bitwise. The complete command takes 218,137 no-stall simulation cycles
in either version. These are standalone behavioral-bank and OOC synthesis
results; integrated placement, routing, board timing, and full-model output
remain unverified. The 256 PEs still dominate LUT use because each performs
per-output shared-exponent alignment. Further reductions need a separate
numeric and throughput comparison rather than assuming this version is optimal.
