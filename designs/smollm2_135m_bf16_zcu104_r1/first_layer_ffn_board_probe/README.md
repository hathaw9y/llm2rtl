# First-layer full FFN intermediate diagnostic on ZCU104

This 100 MHz ZCU104 design executes the existing first-layer no-KV ISA program
for prefill32 and one cold token. The A53 emits ISA records and DDR source
addresses. PL performs the model operations. A reusable diagnostic BRAM records
**accepted PL writes** at four FFN boundaries: post-attention RMSNorm B2
(576 channels per token), gate projection B8 (1536), up projection B9 (1536),
and SiLU × up B10 (1536). These taps are not independent reads from the
compute banks. The checkpoint is `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`.

The A53 adds diagnostic END records after the last up tile and SiLU operation
in prefill, and after post-norm and SiLU in the cold-token run. It waits for
DONE before reading a tap, then selects the next FFN bank. The existing ISA
commands and compute module operations are unchanged. The tap retains data
across END boundaries while a stage continues. The C app compares every
channel with frozen Hugging Face BF16 values and prints every observed BF16
word. Approximate UART log size is over 1 MB, so enable logging before run.
Each `FFN_FULL` UART line contains at most 128 channels and includes its row
and channel offset; the analyzer rejects missing or duplicate chunks.

On the PC connected to the board, extract the handoff, verify hashes, and
run the matched BIT and ELF:

```sh
tar -xzf first_layer_ffn_board_handoff.tar.gz
cd first_layer_ffn_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

UART is 115200 8-N-1. In an existing GNU Screen UART session: press `Ctrl+A`,
then `:`, enter `logfile /absolute/path/uart_ffn.txt`, and then enter `log on`.
Wait for `BOARD FIRST LAYER ISA PASS` or `FAIL` before stopping the log.

Expected complete capture sizes:

| Case | B2 post-norm | B8 gate | B9 up | B10 SiLU × up |
|---|---:|---:|---:|---:|
| prefill32 | 18,432 | 49,152 | 49,152 | 49,152 |
| cold token | 576 | 1,536 | 1,536 | 1,536 |

In the repository, analyze the captured UART log:

```sh
python designs/smollm2_135m_bf16_zcu104_r1/scripts/analyze_first_layer_ffn_log.py \
  /absolute/path/uart_ffn.txt > ffn_analysis.json
```

With the pinned local checkpoint and PyTorch environment, add
`--input-conditioned` to replay the Hugging Face FFN using the **observed
board B5 attention residual**. The analyzer then reports `against_board_b5`
metrics for each stage. This distinguishes error propagated from the
attention output from error introduced inside FFN. When the B1 down-projection
capture is present, the same option also compares it with Hugging Face
`down_proj` applied to the **observed B10 SiLU × up values**. This isolates
down-projection arithmetic from its input difference. This replay runs on the
host after the board test; the baremetal A53 does not compute model tensors.

An initial board run captured all four FFN boundaries but stopped before
B1/B0 comparison because it tested the SiLU write count after the next START
had cleared that count. The ELF in this package checks the count immediately
after the SiLU END and corrects the first-16 B5 tap address. The BIT/XSA did
not change. The corrected ELF ran on a physical board: all FFN taps and B1/B0
were captured for prefill32 and a cold token. The strict comparison with the
original Hugging Face output still prints `BOARD FIRST LAYER ISA FAIL`.
Comparing B1 against Hugging Face down projection on the **observed board
B10** produces zero legacy-threshold failures, and observed B0 equals BF16
addition of observed B5 and B1 for every value. A cold single token has no
populated KV cache and is not a context-aware decode test.
