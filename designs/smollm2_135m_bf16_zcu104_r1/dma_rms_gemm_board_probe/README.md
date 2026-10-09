# SmolLM2 BF16 RMSNorm + GEMM board checkpoint

This checkpoint targets the exact SmolLM2-135M revision
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`, ZCU104, A53 standalone,
and a 150 MHz PL clock. It tests one first-layer RMSNorm and a 16-column
one-hot GEMM projection for both 32-token prefill and one-token decode. The
one-hot projection makes GEMM's 16 outputs equal the first 16 RMSNorm values
so both executors can be checked with the same BF16 golden values.

The A53 copies pinned BF16 input, gamma, and projection weights into DDR,
flushes the cache, then publishes this command BRAM sequence:

```text
DMA_LOAD B0 <- DDR input
DMA_LOAD B3 <- DDR gamma
RMSNORM B0, B3 -> B2, rows=32 or 1
DMA_LOAD B3 <- DDR projection weights
GEMM B2, B3 -> B4, M=32 or 1, K=576, N=16
END
```

The dispatcher waits for each bank dependency and releases B0/B3/B2 after
RMSNorm's identifiable completion response. It then allows B3 to be reloaded.
RMSNorm computes the mean square, inverse root, BF16 cast, and gamma multiply
in PL. The A53 does no model tensor arithmetic. The probe records accepted
B2 and B4 writes in separate readback buffers; this is a write-port check,
not a later read of the physical bank memories. The B2 tap stores only the
first 16 values of each row for the board comparison; the independent RTL
golden test checks every output element.

RMSNorm uses a signed Q16.16 reduction, Q32.32 mean square with epsilon
rounded to 42,950 Q32 units, an integer square root, a Q32 reciprocal, and
round-to-nearest-even BF16 casts before and after gamma multiplication.
The executor rejects nonfinite values, BF16 magnitudes at least 32,768,
or a sum-of-squares overflow. Subnormal underflow remains an approximation.
With ideal bank ports, standalone RTL takes 186,752 cycles for 32 rows and
5,836 cycles for one row. Those are executor latencies, not board throughput.

## Verification and build

From the repository root with Vivado/Vitis 2025.2:

```sh
bash designs/smollm2_135m_bf16_zcu104_r1/scripts/run_dma_rms_gemm_board_probe_xsim.sh
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/create_dma_rms_gemm_board_probe_v4.tcl
vivado -mode batch -source designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_rms_gemm_board_probe_v4.tcl
XILINX_VITIS_DATA_DIR=/tmp/smollm2_dma_rms_gemm_vitis vitis -s designs/smollm2_135m_bf16_zcu104_r1/scripts/build_dma_rms_gemm_board_app.py
```

The Vitis app builder can be replaced by
`scripts/build_dma_rms_gemm_board_app_existing_bsp.py` when using the
repository's existing ZCU104 A53 standalone BSP. The BIT, XSA, HWH and PS
initialization must all come from this checkpoint's build.

## Board run

Copy `dma_rms_gemm_board_probe_artifacts.tar.gz` to the host PC connected to
the ZCU104, then extract it. The archive SHA-256 is
`d08b406bd94256437fdb7567620a9a39f54c898d974413c0b9e6bbe5a25e359e`.
Set JTAG boot mode, connect USB JTAG, and open `psu_uart_0` at 115200 8N1.
From the directory containing the archive:

```sh
echo 'd08b406bd94256437fdb7567620a9a39f54c898d974413c0b9e6bbe5a25e359e  dma_rms_gemm_board_probe_artifacts.tar.gz' | sha256sum -c -
tar -xzf dma_rms_gemm_board_probe_artifacts.tar.gz
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Expected UART tail:

```text
prefill32 RMS compare=512 mismatches=0
prefill32 GEMM compare=512 mismatches=0
decode RMS compare=16 mismatches=0
decode GEMM compare=16 mismatches=0
BOARD DMA_LOAD RMSNORM GEMM PASS
```

The comparator allows at most two BF16 ULP per value. The independent
standalone RTL test checks all 18,432 prefill and 576 decode RMSNorm values
against the checkpoint's first-layer BF16 reference. A separate numerical
sweep across all 120 RMSNorm calls (1,140,480 values) in the selected
prefill/decode trace found no value above 2 ULP; RTL also passed the
32-row case containing the largest observed input (20,352). The user reported
the expected UART result with zero mismatches for prefill and decode on the
physical ZCU104 on 2026-10-01. The recorded result is limited to the first 16
RMSNorm and GEMM output features per row observed at accepted bank write ports;
the UART report does not include the host-side BIT/ELF hash output. See
`../evidence/smollm2_dma_rms_gemm_board_probe/board_150mhz/run_001/user_uart_report.json`.
