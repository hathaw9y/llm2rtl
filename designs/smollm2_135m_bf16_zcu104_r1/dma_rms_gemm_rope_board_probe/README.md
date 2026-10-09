# ZCU104 DDR DMA_LOAD + RMSNorm + GEMM + RoPE probe

This bounded test runs an ISA command stream on the 150 MHz PL executor. It
checks decode (1 token) and prefill (32 tokens). The A53 copies pinned input,
gamma, projection, and RoPE coefficient vectors to DDR, loads command BRAM,
starts the dispatcher, and compares captured PL write data. It does not perform
model tensor operations.

The projection is an offline one-hot 192 x 576 weight tile reused for Q and K.
The input, RMSNorm gamma, and RoPE coefficients come from SmolLM2-135M revision
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. Consequently this probe
tests command routing, DMA, RMSNorm, GEMM, and RoPE together, but does not
validate the checkpoint's Q/K projection weights or complete model inference.

## Command sequence

1. DMA_LOAD B0 input and B3 gamma.
2. RMSNORM B0/B3 to B2.
3. DMA_LOAD B3 one-hot projection tile.
4. GEMM B2/B3 to B4 for Q (three N=192 tiles) and B5 for K (one N=192 tile).
5. DMA_LOAD B7 RoPE coefficients.
6. ROPE B4 and B5 in place, then END.

The command BRAM holds 12 records. The board probe captures the first 16 BF16
elements per row from each RoPE write stream, and counts all Q/K writes. The
comparison permits at most 2 BF16 ULPs per captured value.

## Local verification

```bash
cd /home/shmin/llm2rtl
bash designs/smollm2_135m_bf16_zcu104_r1/scripts/run_dma_rms_gemm_rope_board_probe_xsim.sh
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_dma_rms_gemm_rope_board_artifacts.py
```

The second command requires the routed BIT/XSA/HWH/ELF bundle in `artifacts/`.

## Physical board run

Copy the complete `artifacts/` directory to the host PC with Vivado/Vitis
2025.2. Keep the files together. On the host, power the ZCU104 in JTAG boot
mode, connect JTAG and UART, then run:

```bash
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. Expected final line:

```text
BOARD DMA_LOAD RMSNORM GEMM ROPE PASS
```

Also expect `prefill32 Q RoPE compare=512 mismatches=0`,
`prefill32 K RoPE compare=512 mismatches=0`, and both decode Q/K checks with
`compare=16 mismatches=0`. A physical board PASS requires the UART output
from this exact BIT and ELF; simulation and routed reports alone do not count.
