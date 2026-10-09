# First-layer B5/B1 full-stage diagnostic board probe

This ZCU104 100 MHz build executes the existing first-layer no-KV ISA
program for prefill32 and a cold single token. The PL captures all accepted
ADD writes to B5 (attention residual), all accepted GEMM lane writes to B1
(down projection, overwriting the earlier output projection), and all
accepted final ADD writes to B0. These taps observe PL write data; they are
not independent BRAM bank readback. The A53 emits ISA records and DDR
addresses, then reads the taps and compares them to frozen BF16 model
values. It does not compute model tensor operations.

The checkpoint is `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`.

On the PC connected to the board, start logging the UART **before** the
test. In an existing GNU Screen UART session, use `Ctrl+A`, `:`, then
`logfile /absolute/path/uart_stage.txt` and Enter; repeat with `log on`.
The UART setting is 115200 8-N-1. Then run in another terminal:

```sh
cd first_layer_stage_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

The expected diagnostic counts are 18,432 BF16 values each for prefill32
B5, B1, and B0; 576 each for the cold token. Both B5 and B1 have full
`STAGE_FULL` rows in the UART output. To analyze the saved log:

```sh
python3 scripts/analyze_first_layer_stage_log.py /path/to/uart_stage.txt > stage_analysis.json
python3 scripts/analyze_first_layer_full_output_log.py /path/to/uart_stage.txt > final_analysis.json
```

Run the analyzers from the extracted package's design directory so their
relative golden headers are present. The legacy numerical gate reports a
failure when BF16 distance exceeds 16 ULP and absolute error exceeds
0.002. A numerical FAIL does not invalidate the routed hardware artifact;
compare the stage metrics to locate where the error first grows. The cold
single token has no populated KV cache, so it is not context-aware decode.
