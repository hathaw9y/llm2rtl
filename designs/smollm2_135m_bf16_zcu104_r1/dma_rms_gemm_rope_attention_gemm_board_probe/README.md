# ZCU104 shared GEMM attention mode

This 100 MHz build routes ISA `GEMM` (3), `ATTN_SCORE` (6), and
`ATTN_VALUE` (8) through one 16 × 16 BF16 systolic array. The dispatcher
still owns the PC and bank lifetimes. The fabric selects the logical
compute channel and bank roles for each command and returns the matching
completion, including the three bank IDs. The PS loads commands and DDR
input data and compares results; it does not compute attention tensors.

For `ATTN_SCORE`, the array reads Q from B4 and the grouped K cache from
B8. It loops over nine query heads, maps each three heads to one KV head,
and splits the key dimension into N tiles of at most 192. Scores are
scaled by 1/8, rounded to BF16, and written to B10 with future and
padded positions zero. For `ATTN_VALUE`, it reads B10 probabilities and
the B9 V cache, transposes each V tile inside the loader, accumulates
over `kv_len`, and writes the B11 context. Both modes use 128-bit bank
reads and two-byte output strobes. Ordinary GEMM retains 256-bit paired
reads. No new ISA opcode or command record is needed.

Independent XSIM compared all score and context elements for full
prefill32 and decode1 against pinned checkpoint BF16 vectors. Maximum
differences were 1 BF16 ULP for score and 3 BF16 ULP for context. A
synthetic `kv_len=193` case checked the score N tile boundary and value
K reduction boundary. The existing normal GEMM regression and integrated
prefill32, focused one-key, and decode1 (`kv_len=33`) command-stream
simulations also pass. The integrated
checks compare the first 16 Q, score, probability, and context values per
query row after the complete two-chunk ISA program.

The board probe runs the existing two command-BRAM chunks: DDR loads and
Q GEMM/RoPE, then DDR K/V loads followed by ATTN_SCORE, SOFTMAX, and
ATTN_VALUE. The A53 compares the first query head's score, probability,
and context. This is a first-layer probe, not full-model inference.

## Run on the host PC

After the new artifacts are built, copy the entire `artifacts/` directory
to the host PC. Put ZCU104 in JTAG boot mode and connect JTAG and UART:

```bash
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Use `psu_uart_0` at 115200 8-N-1. The expected final line is
`BOARD ATTN_SCORE SOFTMAX ATTN_VALUE PASS`.

The user reported this PASS line with zero mismatches for Q, score,
softmax, and context in both prefill32 (512 comparisons each) and decode
(16 comparisons each). The [board run report](board_run_user_report.json)
preserves the supplied UART output. This establishes a user-reported
first-layer board probe pass. The UART text includes the checkpoint revision
but no BIT or ELF hash, so the exact programmed artifact identity follows
from the handoff context rather than from the UART text itself. This does
not establish full-model inference.
