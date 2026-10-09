# 16x16 GEMM systolic executor

The array is output-stationary: each of its 256 PEs keeps one output
accumulator. Activation values enter from the left and advance right; weight
values enter from the top and advance down. Row and column injection are
skewed by their array indices, so a PE sees matching K positions in order.
K is split into internal chunks of at most 16, while the public GEMM ISA
still requests the full K and one N tile. A K chunk ends only after the
last MAC has drained through the array. PE accumulators persist across K
chunks and are cleared when the next 16x16 M/N output tile starts.

The existing role-3 and role-4 bank read ports each return one 128-bit word.
Before a wavefront, the controller fetches the two or three row-major words
covering each active row/column of the K chunk. The 8 BF16 lanes are placed
in small 16x16 local tile buffers. This supports odd K and bank word
crossings without changing the DDR layout or ISA. One read pair is outstanding
at a time; this keeps the existing three-cycle response association simple,
but bank loading currently limits throughput. The output port writes one
BF16 result per handshake with two byte strobes; it does not pack eight
results per write. This is another throughput limit.

Each PE uses a registered 8x8 BF16 significand product attributed with
`USE_DSP`, followed by a 32-bit shared-exponent accumulator with four guard
bits. The product is exact; its K order and
alignment truncation rule match the scalar reference, but the shorter guard
field can change BF16 results near rounding boundaries. The initial 64-bit
and 36-bit arrays exceeded the ZCU104 LUT count. The 32-bit accumulator
cannot overflow for at most 1,536 finite BF16 products aligned to the
largest exponent: 1,536 × 65,025 × 2^4 = 1,598,054,400 < 2^31.
The measured checkpoint layer-0 Q projection prefill sample covers 32 rows
and 16 columns (512 outputs), and the decode sample covers 16 outputs;
all are bit identical to exact-rational BF16 dots and PyTorch BF16. This
does not establish model-wide numerical accuracy.
The common sequential BF16 nearest-even rounding unit visits each output
after all K chunks complete. On a matching completion, the executor returns
the three accepted bank IDs for dispatcher release. Nonfinite input returns
an error before any output write from the affected command; because prior
M/N tiles may already have written, dispatcher error handling must invalidate
the destination bank.

The scalar executor remains a reference implementation. This array is a new
GEMM opcode implementation in the ISA specification. Vivado 2025.2 OOC
synthesis of the full array at a 5.000 ns constraint reports 190,018 LUTs,
38,206 flip-flops, 263 DSPs, and WNS +0.479 ns. The successful flow uses
`-flatten_hierarchy none`; the default flattened DSP synthesis stalled before
a report and was stopped. The post-synthesis DRC has 783 DSP pipelining
advisory warnings and no Error-severity checks. These reports establish a
standalone module result, not a placed/routed board result.

With ready bank ports and no stalls, XSIM measures 218,137 cycles for a
32x192x576 GEMM command. At an assumed 200 MHz that is 1.090685 ms, about
97.45 times faster than the 21,258,241-cycle scalar baseline on that shape.
The bank loader permits only one read pair outstanding and the destination
writer emits one BF16 value per write, so the 256 MAC PEs are active only a
fraction of the command time. The XPM bank-fabric attachment and the other
model executors remain separate implementation work; this module result is
not a working ZCU104 bitstream or complete model acceleration.
