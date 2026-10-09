# First-layer attention output board comparison

This probe reuses the routed 100 MHz ZCU104 BIT/XSA from the ADD checkpoint.
Only the A53 application and its offline reference vectors changed. The ISA
program still uses `DMA_LOAD`, `GEMM`, `ADD`, and `END` across command BRAM
chunks. The A53 copies pinned BF16 inputs and the checkpoint's actual
`layer0.self_attn.o_proj.weight` into DDR; tensor operations run in PL.

The third chunk loads three `[192,576]` output-column weight tiles into B3,
runs GEMM from context B11 into B1, loads a zero tensor into B0, then executes
`ADD B0,B1→B5`. This exposes the attention output after `o_proj` through the
existing B5 result tap. A fourth chunk reloads the original hidden input
into B0 and executes `ADD B0,B1→B5` for the post-attention residual. Both
outputs are compared with a fresh Hugging Face eager BF16 model run at the
pinned checkpoint revision. The offline golden context passed through the
same `o_proj` matches the Hugging Face attention output bit for bit.

The existing GPIO tap exposes **the first 16 of 576 BF16 values per row**.
The board therefore compares 512 values for prefill32 and 16 for decode1
for each of `o_proj` and residual. All 576 output values are computed in PL.
K/V cache operands are loaded from pinned checkpoint reference data. The
acceptance threshold for `o_proj` and residual is at most 16 BF16 ULP **or**
0.002 absolute value error, allowing small absolute differences near zero.
The preexisting Q, score, softmax, and context checks retain their thresholds.

On the host PC with the ZCU104 in JTAG boot mode:

```sh
cd first_layer_attention_output_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. Expected lines include
`prefill32 o_proj compare=512 mismatches=0`,
`prefill32 residual compare=512 mismatches=0`,
`decode o_proj compare=16 mismatches=0`,
`decode residual compare=16 mismatches=0`, and
`BOARD FIRST LAYER ATTENTION OUTPUT PASS`.
