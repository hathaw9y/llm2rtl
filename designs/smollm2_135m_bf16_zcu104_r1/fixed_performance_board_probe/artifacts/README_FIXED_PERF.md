# Fixed SmolLM2 power and throughput evaluation

This ELF uses the existing 100 MHz BIT and the same SD `MODEL.BIN` as the
numeric 30-layer probe. It runs fixed prefill32 followed by decode1. It emits
`PERF_BLOCK` records with A53 timer microseconds. The timed scope includes ISA
issue, DMA, PL execution and completion polling. It excludes SD loading,
per-layer golden comparisons and final UART reporting. Each layer still checks
the ADD write count. The existing numeric ELF remains the correctness evidence.

Copy `smollm2_fixed_perf_sd.elf` and `run_fixed_perf_sd.tcl` next to
`zcu104_first_layer_kv_board_probe.bit` and `psu_init.tcl`. With `MODEL.BIN`
on the SD card, capture UART and run:

```
xsct -nodisp run_fixed_perf_sd.tcl
```

The UART must contain exactly one `PERF_BLOCK prefill32 0 32 ...` and one
`PERF_BLOCK decode1 32 33 ...` followed by
`BOARD FIXED PERFORMANCE ISA EXECUTION COMPLETE`. Measure
average input power separately over each block if reporting board TOPS/W.
After capturing UART as `uart_perf.txt`, calculate time and nominal operation
throughput with:

```
python3 evaluate_energy_efficiency.py --log uart_perf.txt
```

For measured efficiency, record mean board input power separately during the
`PERF_BEGIN` to `PERF_BLOCK` intervals and add, for example:

```
python3 evaluate_energy_efficiency.py --log uart_perf.txt \
  --prefill-power-w 4.2 --decode-power-w 3.8 \
  --power-source measured --power-scope board_input \
  --json-out energy_result.json
```

The W values above are examples, not measurements. Use your measured values.
The script reports nominal GEMM+attention TOPS/W and tokens/J. The operation
count is checked against the fixed ISA traces. The time excludes model SD
loading and UART output. If power comes from Vivado instead of a meter, select
`--power-source vivado_estimate --power-scope on_chip_estimate`; the output
will be labeled estimated efficiency.

The 100 MHz BIT is reused; this package changes only the A53 ELF and runner.
