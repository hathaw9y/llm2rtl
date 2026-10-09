# SmolLM2-135M interactive ZCU104 handoff

This app reuses the physically exercised 100 MHz bitstream. The A53 loads the
existing `MODEL.BIN` from the FAT SD BOOT partition and generates ISA commands
for each input block. PL executes all model tensor operations through lm_head.
The host PC performs checkpoint tokenizer encoding, greedy selection from the
BF16 logits received over UART, and text decoding. The PS does not calculate
model tensor values or select output tokens.

The checkpoint is `HuggingFaceTB/SmolLM2-135M` revision
`93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. It is a base completion
model with no chat template. `--qa` supplies a simple `Question: ...\nAnswer:`
prompt, but answer quality is not guaranteed by the accelerator test.

## Host setup

Keep the already verified `MODEL.BIN` on the SD card. Extract
`interactive_board_handoff.tar.gz` inside the existing
`full_model_board_probe/artifacts` directory. It creates `interactive/` next
to the routed BIT and `psu_init.tcl`:

```sh
tar -xzf interactive_board_handoff.tar.gz -C full_model_board_probe/artifacts
cd full_model_board_probe/artifacts/interactive
sha256sum -c SHA256SUMS
python3 -m pip install transformers pyserial
```

Close `screen` on the PS UART; the host script needs exclusive access to that
serial port. Program the board in one terminal:

```sh
xsct -nodisp run_on_zcu104_interactive.tcl
```

In another terminal, use the same directory:

```sh
python3 ask.py --port /dev/ttyUSB1 --qa \
  --prompt 'What is the capital of France?' --max-new-tokens 8 \
  2>&1 | tee interactive_run.log
```

Replace `/dev/ttyUSB1` with the PS UART device previously used by `screen`.
The host script can reconnect to a running board and issues `RESET` for a new
prompt. The maximum is 1024 tokens including prompt and generated tokens;
prefill runs in blocks of up to 32. The last prefill block and every decode
step produce 49,152 BF16 logits. Intermediate prefill blocks skip lm_head.

The script reports `board=... tok/s` from the A53 timer around command issue,
PL execution, DMA and completion polling. It excludes UART logits transfer.
`UART_included=... tok/s` measures the host block round trip, including the
98,304-byte UART logits payload when present. At 115200 baud, the wire payload
alone needs at least 8.53 seconds per generated token. These are measurements
only when the script runs on the physical board; no rate is inferred from the
earlier timestamp-free UART logs.

The host checks a CRC32 over each logits frame. An `ERROR` from the board,
short frame, invalid size, or CRC mismatch aborts the run. The board's earlier
fixed prefill32/decode1 checkpoint remains the only physical numeric comparison
so far; interactive prompt output is pending board execution.
