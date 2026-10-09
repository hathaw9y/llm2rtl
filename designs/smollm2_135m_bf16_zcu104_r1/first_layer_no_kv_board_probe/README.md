# First-layer ISA board probe without KV cache

This 100 MHz ZCU104 build runs SmolLM2-135M layer 0 from token embeddings
through the post-FFN residual. The A53 supplies token IDs, DDR addresses,
weight bytes, and ISA records. All model tensor operations run in PL. The
program uses `DMA_LOAD`, `RMSNORM`, `GEMM`, `ROPE`, `ATTN_SCORE`, `SOFTMAX`,
`ATTN_VALUE`, `ADD`, `SILU_MUL`, and `END`. Each `END` drains a command-BRAM
chunk; bank contents and tensor progress remain available to the next chunk.

The two cases are contiguous prefill of 32 tokens from position 0 and a cold
single token at position 0. The latter is not context-aware decode. The
program does not load, store, or reuse DDR KV cache. It computes current K
and V directly into B8 and B9, rotates K in B8, and returns the final FFN
residual in B0. The GPIO tap exposes the first 16 of 576 BF16 values per row;
the PL computes all 576.

The output comparison accepts at most 16 BF16 ULP or 0.002 absolute error.
The app reports the maximum ULP distance and the first failing values. This is a physical-board
test criterion; offline interpreter and RTL simulation do not establish
board success.

The first user-run board result completed all seven prefill32 chunks but
failed the final comparison at 4 of 512 sampled values. See
`board_run_user_report.json`. The original app did not run the cold
single-token case after that failure. The revised app and diagnostic ELF
are untested on the board; `README_DIAGNOSTIC.md` gives the next check.

On the host PC with the ZCU104 powered in JTAG boot mode:

```sh
cd /path/to/smollm2_135m_bf16_zcu104_r1/first_layer_no_kv_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. Success would require
`prefill32 final ADD compare=512 mismatches=0`,
`single_token_cold final ADD compare=16 mismatches=0`, and
`BOARD FIRST LAYER ISA PASS`. Any dispatcher error, timeout, write-count
error, or mismatch is a failed board checkpoint.
