# SmolLM2-135M BF16, 30-layer ZCU104 ISA board probe

This handoff reuses the routed 100 MHz BIT/XSA from the layer-0 KV checkpoint. No HDL or bitstream change was made. The A53 constructs ISA records at runtime from token IDs, dimensions, absolute positions, and static DDR addresses. It does no model tensor arithmetic. The PL performs all 30 decoder layers, DDR K/V stores and reloads, final RMSNorm, 256 lm_head GEMM tiles, and logits DMA_STORE.

The fixed board test runs prefill32 (tokens 11, 28, ..., 538) and one continuation decode token 555 at position 32. Reference logits and 16 diagnostic channels at every layer were frozen from checkpoint `93efa2f097d58c2a74874c7e644dbc9b0cee75a2`. A53 comparisons occur only after PL END/DONE and never feed model computations. The test ends at logits; it does not choose or generate the next token.

The host loads `ddr_static_bf16.bin` directly into DDR at `0x57A00000` using XSCT `dow -data`. The image contains tied embeddings/lm_head weights, all 30 layers' BF16 weights, final norm, and RoPE values. The full 1024-token K/V and logits reservation ends at `0x69149280`. The static image is 269,161,088 bytes; total model DDR reservation is 292,852,352 bytes. Loading the large image over JTAG may take time. Do not run another program that overwrites this DDR region between the load and the probe.

The command BRAM holds 16 records. The A53 emits at most 15 operations and then END, waits for DONE, and loads the next fragment. It also ends each layer so the output tap can be compared before the next layer. The generated stream has 2,679 prefill operations in 187 fragments and 2,648 decode operations in 185 fragments. Each layer's K/V is written with DMA_STORE, drained by FENCE, and reloaded for attention. A final FENCE drains logits DMA_STORE.

From the extracted handoff on the host PC:

```sh
cd full_model_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct -nodisp run_on_zcu104.tcl
```

Capture `psu_uart_0` at 115200 8-N-1. The app reports one summary per layer and a 49,152-value logits comparison for prefill and decode, including actual and reference top-1 IDs. The expected completion marker is `BOARD FULL MODEL ISA EXECUTION COMPLETE; REVIEW LOGITS`. This marker means command execution and DDR readback completed; numerical acceptability must be evaluated from the reported errors and top-1 behavior. A timeout or dispatcher/DMA error prints `BOARD FULL MODEL ISA ERROR`.

The Python 16-record ISA interpreter and runtime C wire records were checked against the checkpoint exactly before board execution. The physical board result remains pending.
