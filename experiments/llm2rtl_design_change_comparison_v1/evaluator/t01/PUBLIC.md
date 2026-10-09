# T01 acceptance criteria

Change the production shared GEMM executor from a physical 16x16 array to 8x16.
Retain command M counts up to 32, N tiles up to 192, operand packing and per-output
K arithmetic order. Dense GEMM, ATTN_SCORE and ATTN_VALUE must use the same array.
Exactly 128 PEs must be instantiated, with no retained secondary 16x16 array.

Verify M row tails around 8, 16 and 32, N column tails and offsets, K transitions,
prefill and cached one-row attention. The numerical equivalence reference is the
original hardware arithmetic, not a float GEMM approximation. Complete destination
banks, including untouched BF16 lanes, must match bit-for-bit. Respect independent
bank-ready stalls, registered read latency, output strobes and completion
backpressure. Return correct completion tag, error and released bank identities.
Reject invalid dimensions without output writes.

Public requirements include M=1,7,8,9,16,17,31,32; N=1,7,16,17,191,192;
K=16,64,576,1536, selected only when the real bank capacities permit the shape.
Attention uses nine query heads grouped over three KV heads, causal masking and
all 576 output channels. Performance improvement is not a pass requirement.

Common interpreter, integration, ABI/source identity, synthesis and constrained
100MHz timing gates apply. Independent executor tests alone do not establish
coupled softmax, full-model or board correctness. Physical FPGA is a separate
endpoint. Complete this pilot without extra human guidance.
