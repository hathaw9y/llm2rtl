# First-layer full B0 output board comparison

This 100 MHz ZCU104 probe executes the existing no-KV first-layer ISA
program. The PL writes the post-FFN residual to B0. A read-only diagnostic
tap captures all 2304 accepted 128-bit ADD writes for prefill32, exposing
all 32 × 576 BF16 output values over GPIO after dispatcher DONE. The A53
loads ISA records and DDR operands and compares readback with frozen
checkpoint `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`; it does not
perform model tensor operations.

Run on the PC attached to the physical board, with JTAG boot and UART at
115200 8-N-1. In one terminal, replace `/dev/ttyUSB0` with the board's
actual UART device and start capture before programming:

```sh
SERIAL_DEV=/dev/ttyUSB0
stty -F "$SERIAL_DEV" 115200 raw -echo -ixon -ixoff -crtscts
cat "$SERIAL_DEV" | tee board_uart.log
```

In another terminal, run:

```sh
cd first_layer_full_output_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Capture the **entire UART log to a file**, including all `FINAL_FULL` lines.
The expected counts are `prefill32 final ADD compare=18432` and
`single_token_cold final ADD compare=576`. An old 16-ULP/0.002-absolute
criterion is still printed for continuity; the host analyzer reports MAE,
RMSE, normalized RMSE, maximum absolute error, and largest-error locations:

```sh
cd <extracted-design-directory>
python3 scripts/analyze_first_layer_full_output_log.py /path/to/board_uart.log \
  > full_output_analysis.json
```

The analyzer must run with the `scripts/` and
`first_layer_full_output_board_probe/full_output_vectors.h` paths from this
design package. `single_token_cold` begins at position 0 with no prior KV;
it is not context-aware decode. RTL routing evidence and physical board
results must be reported separately.
