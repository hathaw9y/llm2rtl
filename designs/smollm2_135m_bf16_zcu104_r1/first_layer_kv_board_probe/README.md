# Layer-0 DDR KV handoff (ZCU104, 100 MHz)

This probe runs the checkpoint's first decoder layer for prefill32 and then decode1 at absolute position 32. The A53 writes only ISA records and static input data. PL computes Q/K/V, writes post-RoPE K and V to DDR through S2MM, waits for the FENCE, loads all history through MM2S, computes attention and FFN, and exposes accepted final ADD writes for comparison. The A53 reads DDR K/V and the output tap only after the ISA chunk finishes; its comparisons do not participate in inference.

The command BRAM holds 16 records. Each chunk contains at most 15 operations plus END. END waits until work is done, reports DONE, and keeps bank and DDR state. The A53 then loads the next chunk. K/V DDR allocation is 1024 x 192 x 2 bytes per kind, 768 KiB for this layer; the current test uses only 33 rows.

The provided app checks all K/V BF16 values in DDR and all 576 layer-output BF16 values for each row. It reports ULP, max absolute error in micro-units, and mean squared error in nano-units. The numeric pass bound is MSE <= 0.001 and max absolute error <= 0.2 for each compared tensor. Protocol errors, timeouts, wrong output-write count, or numeric bound violations fail the test. This is a bounded hardware test, not a whole-model inference claim.

Run on the host PC after copying the handoff tarball:

```sh
tar -xzf first_layer_kv_board_handoff.tar.gz
cd first_layer_kv_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Capture `psu_uart_0` at 115200 8-N-1. Expected final marker: `BOARD LAYER0 KV PASS`. Save the complete UART log, including both `DDR key`, `DDR value`, `prefill32`, and `decode1` summaries. Board execution remains user-run and has not yet been observed by the generator.
