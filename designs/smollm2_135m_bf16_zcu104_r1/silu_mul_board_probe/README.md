# SmolLM2-135M BF16 SiLU board probe

This 100 MHz ZCU104 probe app runs a PL ISA command chunk for each of prefill32 and decode1:
`DMA_LOAD B8 gate`, `DMA_LOAD B9 up`, `SILU_MUL B8,B9→B10`, `END`.
The A53 copies pinned layer-0 Hugging Face gate/up tensor bytes into DDR, writes only ISA commands, then reads the diagnostic B10 tap. It does not compute SiLU or multiply. The tap exposes the first 16 of 1536 BF16 results per row (512 prefill and 16 decode values). The executor computes all 1536 values per row. An exact BF16 comparison is required.

The app uses checkpoint revision `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. This is a bounded SiLU probe; gate/up projection GEMM, down projection, and the full FFN are separate steps.

On the host PC with the ZCU104 in JTAG boot mode:

```sh
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. The corrected app identifies itself with `app revision 2: wait for dispatcher DONE`; it waits for the dispatcher DONE status after each command chunk before reading the output count. Expected lines are `prefill32 SILU compare=512 mismatches=0`, `decode SILU compare=16 mismatches=0`, and `BOARD SILU_MUL PASS`. The BIT/XSA are unchanged from the first SiLU handoff; replace the ELF or use this full package. Physical board completion requires the user's run.

User-reported hardware run on 2026-10-02 with app revision 2 passed: prefill32 512/512 and decode 16/16 exact BF16 values, `BOARD SILU_MUL PASS`. This establishes the bounded SiLU probe only; the full first-layer FFN and layer output have not been run end to end on the board. See `board_run_user_report.json`.
