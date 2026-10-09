# GEMM_TILES 128-bit DDR DMA probe

This ZCU104 variant changes the existing 100 MHz DataMover's MM2S and S2MM
AXI memory and stream widths from 64 to 128 bits. The PS HP0 interface was
already 128 bits. The two DMA directions still share one SmartConnect master
and HP0 port. The 128-bit local bank width, BF16 compute executors, ISA,
runtime program, static model image, and test tokens are unchanged.

`DMA_DATA_WIDTH` is a 64-bit default parameter through the common DataMover
channels and model fabric. Only the new board wrapper selects 128. This keeps
the previous 64-bit design buildable. The DMA command queue now checks 16-byte
DDR alignment in this variant; the existing PS `dma()` emitter already
requires 16-byte addresses, lengths, and bank offsets.

The two included ELF files are byte-identical to the `GEMM_TILES` 64-bit
numeric and performance apps. They load the same `MODEL.BIN` from the FAT
partition of the SD card. Its SHA-256 is
`7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`.

After the routed build and packaging complete, copy the handoff archive to
the host PC, extract it into a fresh directory, and run:

```sh
sha256sum -c SHA256SUMS
xsct -nodisp run_dma128_numeric.tcl
xsct -nodisp run_dma128_perf.tcl
```

Capture `psu_uart_0` at 115200 baud. Run the numerical test before using the
performance number: compare every reported layer and both logits results with
the 64-bit baseline. The measured 64-bit `PERF_BLOCK` values were 3,530,422 us
for prefill32 and 1,732,943 us for decode1. The 128-bit build must be timed
and run on the physical board before any throughput improvement is claimed.

Vivado 2025.2 routed the 128-bit design at 100 MHz with setup WNS +1.014 ns,
hold WHS +0.010 ns, and no timing failures. It uses 210,470 CLB LUTs, 186
BRAM tiles, 64 URAMs, and 285 DSPs. The earlier routed 64-bit design used
211,553 CLB LUTs, 184 BRAM tiles, 64 URAMs, and 285 DSPs. The 128-bit MM2S
and S2MM adapter unit tests passed. Physical board execution is pending.
The common DataMover XSIM integration regression also passed for 32-bit and
128-bit banks at read latencies 1 and 3 with the default 64-bit stream. An
Icarus run of the same regression timed out with unknown request signals;
the Vivado XSIM result is the applicable simulator evidence for this build.
