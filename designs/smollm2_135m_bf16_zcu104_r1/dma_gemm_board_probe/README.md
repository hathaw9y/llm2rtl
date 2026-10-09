# ZCU104 DMA_LOAD + GEMM board checkpoint

This checkpoint uses SmolLM2-135M BF16 vectors from revision
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. The A53 copies pinned
activation and Q projection weight bits to DDR and flushes cache. The PL
executes `DMA_LOAD` records for B0 and B3, then GEMM on B2/B3/B4. A test-only
RMSNORM opcode holds the B2 write role while the A53 sends the already
normalized activation bits by GPIO. **No RMS arithmetic is performed** in
this checkpoint. The GEMM executor performs all matrix arithmetic in PL.
The 16×16 PE array uses a two-cycle K step with separate alignment and
accumulation stages for the 150 MHz PL clock.
The bank-router-to-GEMM response boundary registers activation and weight
data, valid, and bank ID together. This adds one clock to each bank-read
response. The 518 response registers are constrained to the
`rsp_bridge_mid` placement region.

The board probe captures accepted GEMM writes to B4 in a separate result
buffer. The A53 reads that buffer and compares BF16 bits with the pinned
prefill32 and decode golden vectors. This verifies executor output at the
accepted bank write port, not a later readback of the physical B4 memory.
The decode chunk reloads B0 and B2 while retaining B3 weights across
`END/DONE`.

## Build

From the repository root with Vivado 2025.2:

```sh
bash designs/smollm2_135m_bf16_zcu104_r1/scripts/run_dma_gemm_board_probe_xsim.sh
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/create_dma_gemm_board_probe.tcl
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_gemm_board_probe.tcl
XILINX_VITIS_DATA_DIR=/tmp/smollm2_dma_gemm_vitis vitis -s designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_gemm_board_app.py
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_dma_gemm_board_artifacts.py
```

If Vitis platform generation stalls, the supplied ELF is compiled against
the earlier ZCU104 Vitis 2025.2 A53 standalone BSP using
`scripts/build_dma_gemm_board_app_existing_bsp.py`. The BIT, HWH, and
`psu_init.tcl` come from this checkpoint's XSA.
For the supplied ELF, run this fallback after building the XSA:

```sh
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_gemm_board_app_existing_bsp.py
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_dma_gemm_board_artifacts.py
```

The routed 150 MHz design meets the 6.666 ns PL clock with setup WNS
+0.267 ns and hold WHS +0.010 ns. The worst setup path remains registered
weight response data to the GEMM tile buffer, with 6.154 ns of route delay.
A comparison build without the response placement constraint met timing at
+0.191 ns setup WNS, so this bundle uses the constrained build. The earlier
200 MHz response-bridge build is preserved in the separately named
`zcu104_dma_gemm_board_probe_rspbridge_bundle.tar.gz` archive.

## Run on the board

Copy the entire `artifacts/` directory to the host PC attached to the
ZCU104. Set JTAG boot mode, connect USB JTAG, and open `psu_uart_0` at
115200 8N1. From the copied directory:

```sh
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Expected UART tail:

```text
GPIO B2 words=2304 OK
prefill32 compare=512 mismatches=0
GPIO B2 words=72 OK
decode compare=16 mismatches=0
BOARD DMA_LOAD GEMM PASS
```

The user reported this expected UART result from the physical ZCU104 on
2026-09-30. The report is recorded under
`evidence/smollm2_dma_gemm_board_probe/board_150mhz/run_001/`.
The UART output does not contain the programmed BIT/ELF hashes, so attribution
to the handed-off 150 MHz package follows the run context. This checkpoint
does not execute RMSNorm or the full model.
