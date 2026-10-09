# ZCU104 cumulative Softmax probe

This 150 MHz BF16 probe runs prefill 32 and decode 1 through an ISA command
stream. The PL executes DDR DMA_LOAD, RMSNorm, GEMM, RoPE and in-place Softmax.
The A53 copies pinned test vectors, loads the command BRAM, supplies pinned
attention scores through a GPIO test port, and compares captured PL writes.
It does not compute Softmax or any other model tensor operation.

ATTN_SCORE is still a **probe channel**, not an implemented score executor.
The probe accepts the ATTN_SCORE command and writes pinned first-layer
checkpoint score words into B10 through its authorized bank role. This makes
the SOFTMAX input valid for the following ISA command. Q/K projection in the
preceding cumulative path uses a synthetic one-hot weight tile, so the pinned
score words are independent of those Q/K values.

The 15-record command sequence fits the single 16-record command BRAM:

1. DMA_LOAD B0 input and B3 gamma; RMSNORM to B2.
2. DMA_LOAD B3 one-hot projection; GEMM to Q B4 and K B5.
3. DMA_LOAD B7 coefficients; ROPE B4 and B5 in place.
4. DMA_LOAD B8 dummy key data; ATTN_SCORE probe writes B10 through GPIO.
5. SOFTMAX B10 in place; END.

The board probe checks every Softmax write address and count. It captures the
first 16 probabilities of the first query head per row, comparing 512 values
for prefill and 16 for decode within 2 BF16 ULP. Standalone RTL simulation
checks all 9 heads, including a 1024-position case.

## Run on the host PC

Copy the complete `artifacts/` directory to the host PC. Power the ZCU104 in
JTAG boot mode and connect JTAG and UART. Then run:

```bash
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. Expected final line:

```text
BOARD DMA_LOAD RMSNORM GEMM ROPE SOFTMAX PASS
```

The board result remains pending until the UART output from this exact BIT and
ELF is supplied. This probe does not establish ATTN_SCORE correctness,
full-model inference, or all-probability physical bank readback.
