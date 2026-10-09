# 128-bit DMA PL and PS performance measurement

This package contains a dedicated profile bitstream and two A53 ELFs.
Vivado 2025.2 synthesis and routing ran on the repository machine. See
`artifacts/verification.json` for the final routed timing and source identities.
Physical board execution and profiling results are pending.

The previous `gemm_tiles_dma128_board_probe.bit` has no profile counters.
Use `smollm2_perf128_sd.elf` with `zcu104_perf128_board_probe.bit` from this package.
The counter unit test and XSIM dispatcher regression passed. The regression
includes a real FENCE waiting for a STORE.

The profile variant retains the 100 MHz clock, one HP0 port, 128-bit DMA,
GEMM_TILES command stream, 93 prefill chunks and 91 decode chunks. PS performs
ISA generation, transport, observation, and timing. The PL executes tensors.
Counters observe control signals and never drive scheduling or tensor data.

## Run the built board package

Extract `perf128_board_handoff.tar.gz` into a fresh directory on the PC
connected to the ZCU104. No synthesis is required on that PC.

```sh
mkdir smollm2-profile128
cd smollm2-profile128
tar -xzf /path/to/perf128_board_handoff.tar.gz
sha256sum -c SHA256SUMS
xsct -nodisp run_perf128_numeric.tcl
```

The numerical probe uses the existing numerical comparison ELF with the new
profile bitstream. Wait for the full-model completion marker and review logits.
Then start a fresh UART capture and run the measurement ELF:

```sh
xsct -nodisp run_perf128.tcl
```

Capture UART at 115200 baud in `uart_profile.txt`. Use the same `MODEL.BIN`
on the SD FAT partition as before (SHA256
`7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`).
After the `BOARD PL PROFILE COMPLETE` marker, analyze the log:

```sh
python3 analyze_pl_profile.py uart_profile.txt
```

`PERF_BLOCK` is PS wall time for ISA generation, fragment upload, execution,
and profile readback. `PROFILE_PS` measures command uploads (including END),
START acknowledgments, DONE polling, and profile readback separately. DONE
polling includes PL execution and is not an independent compute cost. Profile
readback adds overhead, so raw wall time is not directly comparable with the
previous uninstrumented result.

`PROFILE_PL scope index high32 low32` carries exact 64-bit accumulated counts
in hexadecimal. All metrics except 19 and 20 count 100 MHz PL cycles. Counters
clear on every fragment START and freeze outside dispatcher BUSY. PS reads
96 halfwords only after DONE and accumulates all fragments. END drains and
FENCE waits are counted independently. Metrics can overlap and must not be
added to obtain total time.

| Index | Metric | Meaning |
|---:|---|---|
| 0 | pl_busy | Dispatcher BUSY cycles, including fetch, issue and drain |
| 1 | load_pending | At least one issued LOAD has not returned completion |
| 2 | store_pending | At least one issued STORE has not returned completion |
| 3 | gemm_pending | Dense GEMM compute channel has not returned completion |
| 4 | rms_pending | RMSNorm compute channel pending |
| 5 | rope_pending | RoPE compute channel pending |
| 6 | score_pending | Attention score channel pending |
| 7 | softmax_pending | Softmax channel pending |
| 8 | value_pending | Attention value channel pending |
| 9 | add_silu_pending | Shared ADD/SILU channel pending |
| 10 | fence_wait | Valid FENCE in CHECK/ISSUE while outstanding work or guarded banks remain |
| 11 | bank_dependency_wait | Valid non-END/non-FENCE command in CHECK cannot acquire its required banks/channel |
| 12 | issue_ready_wait | ISSUE command has not handshaken, including any FENCE ISSUE wait |
| 13 | end_drain_wait | END waiting for outstanding work or guarded banks |
| 14 | fence_load_pending | FENCE wait while LOAD is pending |
| 15 | fence_store_pending | FENCE wait while STORE is pending |
| 16 | fence_compute_pending | FENCE wait while compute is pending |
| 17 | fence_bank_busy | FENCE wait while ownership/tensor-write guards are busy |
| 18 | any_compute_pending | Any compute channel is pending |
| 19 | load_bytes | MM2S bytes actually accepted at the PL stream, using TKEEP |
| 20 | store_bytes | S2MM bytes accepted by DataMover, using TKEEP |
| 21 | load_stream_stall | MM2S TVALID asserted while PL TREADY is low |
| 22 | store_stream_stall | PL S2MM TVALID asserted while DataMover TREADY is low |
| 23 | load_compute_overlap | LOAD pending and any compute pending simultaneously |

Pending intervals include completion propagation and may include queuing.
They do not measure the raw DDR bus alone. Stream stall counters measure
backpressure on valid beats; they do not include gaps with TVALID low.
FENCE reason counters overlap with each other and with FENCE total.
Use the FENCE percentage to assess the earlier hypothesis. Use LOAD pending,
accepted bytes, load/compute overlap, and GEMM pending together to decide
whether more DMA bandwidth or weight prefetch can help. A new routed build
must still pass setup, hold and DRC before the hardware measurement is valid.

## Rebuild from source

The source archive contains a minimal `llm2rtl` directory tree. Use Vivado
2025.2. An optional `SMOLLM2_PROFILE_BUILD_DIR` environment variable selects
another local disk for the Vivado project. Use the same value for both steps.

```sh
cd llm2rtl
D=designs/smollm2_135m_bf16_zcu104_r1
vivado -mode batch -source "$D/scripts/create_perf128_board_probe_100mhz.tcl"
vivado -mode batch -source "$D/scripts/build_perf128_board_probe_100mhz.tcl"
python3 "$D/scripts/finalize_perf128_board.py"
```
