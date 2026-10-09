# First-layer output quality measurement

This ELF uses the existing 100 MHz BIT and the same ISA program. It adds
`FINAL_VALUES` UART lines for the 16 visible BF16 output channels of every
prefill row and of the cold single-token case. It also retains the earlier
stage diagnostics. The PS compares and prints values; model tensor operations
remain in PL.

On the host PC, in `artifacts`:

```sh
sha256sum -c QUALITY_SHA256SUMS
xsct run_quality_on_zcu104.tcl
```

Capture the complete `psu_uart_0` output at 115200 8-N-1. There should be
33 `FINAL_VALUES` lines: rows 0..31 for prefill32, then row 0 for the cold
single token. The host-side script
`scripts/analyze_first_layer_no_kv_quality_log.py <captured-log>` reads
those lines and reports MAE, normalized RMSE, maximum absolute error, and
the locations of the largest differences against the pinned checkpoint.
Only the first 16 of 576 output channels per row are observable through
this board tap, so these metrics do not cover the complete tensor.
