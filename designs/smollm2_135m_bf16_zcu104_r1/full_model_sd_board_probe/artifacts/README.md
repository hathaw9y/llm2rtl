# SD-backed 30-layer board app

Place the verified 269,161,088-byte `MODEL.BIN` on the SD card FAT BOOT
partition before powering the board. Its SHA-256 must be
`7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`.
The app checks size and CRC32 `db7d52bb` while copying the image to DDR.
It then runs the same ISA prefill32 and decode1 test as the JTAG-loaded app.

Copy the ELF and Tcl into the existing `full_model_board_probe/artifacts`
directory, then run `xsct -nodisp run_on_zcu104_sd.tcl` there. The existing
100 MHz bitstream and psu_init.tcl are reused. No JTAG `dow -data` occurs.
The Tcl halts/resets an A53 app left running by a prior probe, so it can be
rerun with the board powered. Keep the SD card inserted and close any other
XSCT/Vitis JTAG session first.
`run_lm_head_input_sd.tcl` runs a diagnostic ELF that also reads the existing
RMSNorm tap for the first 16 BF16 channels per token. It reports the last
token's first 16 values entering lm_head for prefill and decode, compared
against the checkpoint. The 100 MHz bitstream does not expose the remaining
560 channels directly.
Physical SD load and 30-layer logits results are pending board execution.
