# GEMM_TILES command compression probe

This variant keeps the 100 MHz ZCU104 board architecture and 16 by 128-bit
command BRAM. Opcode 12 (`GEMM_TILES`) replaces a repeated sequence of
`DMA_LOAD` weight tile and `GEMM` commands with one PS-authored descriptor.
The descriptor contains the DDR weight base, full output width, tile width,
K, row range, and bank IDs. The PL dispatcher issues the original DMA and
GEMM requests, waits for bank availability, and retains their completion
tracking. The PS still chooses all operation order and tile parameters. The
macro does not change the BF16 datapath.

`scripts/verify_gemm_tiles_program.py` recompiles the original and compact C
programs and expands each macro in Python. It requires byte-exact equality
with the original 2,679 prefill and 2,648 decode work records. The compact
program has 758 prefill and 727 decode records. To keep the existing board
probe's per-fragment write-address counters valid, PS ends a fragment before
the second RMSNorm, ADD, or other repeated probe kernel in that fragment.
Command fragments fall from 187 to 93 and from 185 to 91. This is a command
count result, not a measured throughput improvement.

`artifacts/smollm2_gemm_tiles_numeric_sd.elf` runs the same fixed prefill32
and decode1 numerical probe. `artifacts/smollm2_gemm_tiles_perf_sd.elf` runs
its timing variant. They require the matching new BIT, `psu_init.tcl`, and
the same `MODEL.BIN` on the SD card FAT partition as the earlier 30-layer
probe. The model file SHA-256 is
`7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`.

After the routed artifacts exist, copy the `artifacts` directory to the host
PC. From that directory run `xsct -nodisp run_gemm_tiles_numeric.tcl` and
capture the board UART at 115200 baud. Then run
`xsct -nodisp run_gemm_tiles_perf.tcl` for timing. The numerical completion
marker only proves command execution and DDR readback; inspect the reported
layer and logits errors. Board execution remains unverified until the user
runs this matched BIT and ELF pair.
