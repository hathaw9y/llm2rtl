# 256-bit GEMM reads over 128-bit tensor-bank words

`bank_layout.json` describes BF16 tensor elements, not the physical transfer
width. Every logical bank still stores 128-bit words with 16 byte enables and
the same byte capacity. The DMA stream is still 64 bits. Only GEMM source
roles 3 and 4 request 256-bit reads from B2, B3, B10 or B11. Other roles and
all writes retain 128-bit transfers.

Each wide-capable logical bank is striped into even and odd 128-bit-word
memories. A write to 128-bit word address `a` selects stripe `a[0]` and stripe
address `a >> 1`. A narrow read returns the selected stripe after the existing
three-cycle latency. A wide read uses an **even** 128-bit word address `a`,
reads both stripes at `a >> 1`, and returns `{word[a+1], word[a]}` at the same
latency. The router rejects odd-address, out-of-range or unsupported-role
wide requests. Ownership remains one lock per logical bank, so narrow and wide
clients never contend for the same bank during one command.

The GEMM executor converts its BF16 element index to a 256-bit row-word index
by shifting right four bits and sends twice that index as the even 128-bit
word address. A 16-element K segment aligned to 16 elements takes one wide
read per row per source bank; an unaligned segment may take two. Its private
wavefront registers still provide sixteen BF16 values per operand per cycle
to the 16x16 array. A single wide bank read does not gather one value from
each of sixteen different row addresses.

For the standalone M32/N192/K576 GEMM case, bank-model XSIM measured 218,137
cycles with 128-bit reads and 162,841 cycles with 256-bit reads (25.3% fewer).
The same selected checkpoint BF16 outputs remain bitwise equal. These cycle
counts exclude DMA loading, other executors, DDR contention and physical
board stalls.

| Standalone post-synthesis measure | 128-bit read | 256-bit GEMM read |
| --- | ---: | ---: |
| GEMM LUT | 137,660 | 138,719 |
| GEMM FF | 42,327 | 46,458 |
| GEMM DSP | 263 | 263 |
| GEMM setup WNS at 5 ns | +0.734 ns | +0.535 ns |
| DMA control fabric LUT | 14,370 | 15,175 |
| DMA control fabric BRAM | 134 | 134 |
| DMA control fabric URAM | 60 | 64 |
| DMA control fabric setup WNS at 5 ns | +0.568 ns | +0.519 ns |

The GEMM and DMA fabric were synthesized separately. These numbers cannot be
added to prove integrated placement, routing, board timing or full-model fit.
