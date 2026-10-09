# First-layer mismatch localization

The first full-layer board run completed seven prefill32 command chunks, then
found 4 of 512 final ADD values beyond the 16 ULP or 0.002 absolute error
criterion. The original A53 app stopped before the cold single-token case.
The report is preserved in `board_run_user_report.json`.

The diagnostic ELF uses the **same BIT** and the same tensor inputs, weights,
ISA records, and 100 MHz hardware. It reads existing GPIO result taps at
the end of selected command chunks. The PS only compares sampled BF16 output
values with offline checkpoint references; it does not execute model tensor
operations. The revised app runs the cold single-token case even when the
prefill final comparison fails.

On the host PC, in `artifacts`:

```sh
sha256sum -c DIAGNOSTIC_SHA256SUMS
xsct run_diagnostic_on_zcu104.tcl
```

Observe `psu_uart_0` at 115200 8-N-1. Save the complete `DIAG` lines and
the two final `compare` lines. `DIAG` reports the number of values exceeding
the existing threshold, maximum BF16 ULP distance, and maximum absolute
error in millionths. Prefill checks input RMSNorm after chunk 2, attention
and post-attention RMSNorm after chunk 3, and SiLU/final ADD after chunk 6.
The cold case checks equivalent stages at its own chunk boundaries. Each
tap samples the first 16 values per row (8 for one-token score/probability).

These measurements identify the first stage where a significant deviation
appears. They do not turn the existing failed full-layer board result into
a pass.
