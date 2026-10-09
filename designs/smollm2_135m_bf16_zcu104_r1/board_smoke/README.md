# ZCU104 BF16 GEMM board smoke test

This bounded test places the 16×16 wide-read GEMM executor and its 13-bank
subsystem in one ZCU104 bitstream. The PS sends fixed BF16 operands and one
ISA GEMM record at a time through AXI GPIO. GEMM multiplication, accumulation,
rounding, and destination writes happen in the PL. The PS reads the resulting
BF16 words and compares them against checked-in pinned-checkpoint golden data.

Scope: layer 0 `self_attn.q_proj`, first 16 output columns, checkpoint
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. Prefill tests 32 input
tokens × 576 inputs and 512 outputs; decode tests one token and 16 outputs.
The generated golden values use exact BF16 input products and round once to
BF16; all 528 values also equal the saved Torch outputs for this sample.
This board test does not exercise the full ISA dispatcher, DDR DMA path, or
the full SmolLM2 model. The separate combined fabric place/route report covers
the GEMM executor together with the DMA/dispatcher/banks, but remains an FPGA
tool result until hardware is run.

## Build

From the repository root with Vivado and Vitis 2025.2 on `PATH`:

```sh
python designs/smollm2_135m_bf16_zcu104_r1/scripts/generate_gemm_board_vectors.py
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/create_gemm_board_smoke.tcl
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/build_gemm_board_smoke.tcl
mkdir -p /tmp/smollm2_vitis_data
XILINX_VITIS_DATA_DIR=/tmp/smollm2_vitis_data vitis -s designs/smollm2_135m_bf16_zcu104_r1/scripts/build_gemm_board_app.py
python designs/smollm2_135m_bf16_zcu104_r1/scripts/verify_gemm_board_artifacts.py
```

The bitstream, XSA, routed timing, utilization, and DRC reports are written
to `board_smoke/artifacts/`. The Vitis app workspace is
`build/gemm_board_vitis_cli/`. The matching ELF is copied into
`board_smoke/artifacts/` next to the BIT, HWH, and XSA. Check the routed timing
report and `verification.json` before using the bitstream. This build's
200 MHz routed WNS is +0.005 ns and WHS is +0.010 ns; both margins are small.
Run `sha256sum -c SHA256SUMS` in `board_smoke/artifacts/` to check the handoff.

## Board procedure

1. Set ZCU104 to JTAG boot, connect JTAG and USB UART, and power it.
2. Open the BSP stdout `psu_uart_0` serial port at 115200, 8-N-1 and start
   recording the serial transcript.
3. On the PC connected to JTAG, run `xsct run_on_zcu104.tcl` from the copied
   `board_smoke/artifacts/` directory. The script programs the matching BIT,
   initializes PS from the exported `psu_init.tcl`, releases PS/PL isolation,
   resets A53-0, downloads the standalone ELF, and starts it. The XSA is
   included for provenance or a Vitis GUI run; the XSCT path uses its exported
   BIT and PS initialization script directly.
4. Save the complete serial transcript. The final line must be `BOARD GEMM PASS` with
   `prefill32 compare=512 mismatches=0` and
   `decode compare=16 mismatches=0`. Any `TRANSFER FAIL`, `GEMM DONE missing`,
   or mismatch line is a failure.
5. Record the board serial number, exact bitstream/XSA/ELF SHA-256 values,
   Vitis version, and UART log together. Physical-board pass is established
   only after that log is reviewed.

AXI GPIO address map from the generated block design: control/status
`0xA0000000`, data high `0xA0010000`, data low `0xA0020000`.
Channel 1 data is at offset 0; channel 2 is at offset 8. The PS toggles
control bit 31 per transaction and waits for status bit 31 to match with
busy bit 30 clear. Status bit 29 is GEMM completion; bit 28 is error.
The loader writes 1152 128-bit weight words to B3 and 2304 activation words
to B2. It reuses the weights for the decode test. The PL writes results to B4.
