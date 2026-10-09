# ZCU104 BF16 residual ADD integration

Opcode 9 runs on compute channel 6 through `smollm2_add_executor`. It reads
two distinct banks through roles 18 and 19 and writes the destination through
role 20. The command payload contains a 1..32 row count in bits [5:0]; other
payload bits are zero. Each row contains 576 BF16 elements. The output is
rounded to BF16 nearest even. Completion returns all three bank IDs after the
last accepted bank write, allowing the dispatcher to release them.

The standalone XSIM compares all 18,432 prefill, 576 decode, and 576 directed
edge values against independently generated BF16 vectors. The integrated
probe first runs the existing Q and attention commands. It then loads
identity weights to B3, runs three GEMM N tiles from B11 context into B1,
and executes `ADD B0,B1,B5`. The A53 compares the first 16 residual values
per row with an offline golden file. Identity weights exercise the PL
projection and ADD connection; they are not the model's learned `o_proj`.

The routed ZCU104 build runs at 100 MHz. Vivado 2025.2 reports setup WNS
+0.866 ns, hold WHS +0.010 ns, and pulse width WPWS +3.500 ns. Routed
utilization is 194,502 LUTs, 87,504 registers, 103.5 BRAM tiles, 64 URAMs,
and 281 DSPs. The included BIT, XSA, HWH, ELF, PS initialization, and
verification record refer to this build.

On the host PC, unpack the handoff and run:

```sh
cd dma_rms_gemm_rope_attention_add_board_probe/artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

Set the board to JTAG boot mode. Observe `psu_uart_0` at 115200 8-N-1.
Expected lines include `prefill32 ADD compare=512 mismatches=0` and
`decode ADD compare=16 mismatches=0`, followed by
`BOARD ATTN_SCORE SOFTMAX ATTN_VALUE ADD PASS`. A physical board result
requires the user's UART log. This probe uses synthetic identity projection
weights and does not establish complete model inference.
