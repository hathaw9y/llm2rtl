# ZCU104 DDR DMA_LOAD board probe

This is a bounded BF16 data-path checkpoint for checkpoint
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. The A53 copies pinned
prefill, decode, and Q projection weight bits into DDR, flushes cache, and
publishes `DMA_LOAD` ISA records. PL fetches the bytes through AXI DataMover
MM2S and stores them in B0 and B3. The A53 reads back every BF16 element and
compares bit patterns. The decode chunk reloads B0 and retains B3.

The command stream uses a test-only read probe at the `RMSNORM` opcode to
hold the legal B0/B3 read roles during readback. It performs no RMS arithmetic
and does not validate GEMM or full model execution. B2's completion state
after this probe is test-only and must not be used by a model program.

## Build and verify

Run from the repository root with Vivado 2025.2 and Vitis 2025.2 on PATH:

```sh
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/create_dma_load_board_probe.tcl
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_load_board_probe.tcl
XILINX_VITIS_DATA_DIR=/tmp/smollm2_dma_vitis_data vitis -s designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_load_board_app.py
python3 designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_dma_load_board_artifacts.py
```

The Vitis platform generator did not complete in the present environment.
The packaged ELF was compiled with the existing Vitis 2025.2 ZCU104 A53
standalone BSP and linker script by
`scripts/build_dma_load_board_app_existing_bsp.py`. The new BIT, HWH, and
`psu_init.tcl` all come from the new XSA. For an independently regenerated BSP,
run the Vitis command above on the host and rerun the artifact verifier.

## Run on the physical board

Copy the entire `artifacts/` directory to the PC attached to the ZCU104.
Put the board in JTAG boot mode, connect the USB JTAG and the `psu_uart_0`
serial port, and open the port at 115200 8N1. From the artifact directory:

```sh
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Expected UART tail:

```text
BANK 0 compare=18432 mismatches=0
BANK 3 compare=9216 mismatches=0
CHUNK prefill DONE
BANK 0 compare=576 mismatches=0
BANK 3 compare=9216 mismatches=0
CHUNK decode DONE
BOARD DMA_LOAD PASS
```

The user reported the expected UART result with zero mismatches on both
chunks. The transcript is stored at
`../evidence/smollm2_dma_load_board_probe/run_001/user_uart.log` and the
scoped board result is recorded in `artifacts/verification.json`. The UART
transcript does not independently attest the host's BIT/ELF hashes.
