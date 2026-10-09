# ZCU104 grouped attention checkpoint probe

This 100 MHz BF16 build runs the first-layer Q path and grouped attention
using ISA records. A53 copies pinned checkpoint inputs and weights to DDR,
loads command BRAM records, and compares captured PL writes. It does not
perform model tensor arithmetic during the run.

Command BRAM has 16 records. The probe executes two chunks and retains B4
and its tensor-valid state across the first `END`/`DONE`:

1. DMA_LOAD B0 input, B3 gamma; RMSNORM B2; three B3 weight tile loads and
   GEMMs to B4; DMA_LOAD B7 coefficients; ROPE B4; END.
2. DMA_LOAD B8 checkpoint K cache and B9 checkpoint V cache; ATTN_SCORE to
   B10; SOFTMAX B10 in place; ATTN_VALUE to B11; END.

The PS reloads command BRAM only after the first DONE and never resets PL
between chunks. The RTL captures the first 16 values of Q, first-head score,
first-head probability, and context per query row. It checks accepted write
addresses/counts for all attention outputs and compares prefill32/decode1
values against pinned checkpoint golden with an 8 BF16 ULP Q and 16 BF16 ULP
attention limit. Standalone RTL verifies complete prefill32 and decode1
score/context outputs exactly. The integrated XSIM test uses one query and
one key to check the two-chunk control and bank path within a short runtime.

## Run on a host PC

Copy the full `artifacts/` directory. Put ZCU104 in JTAG boot mode and attach
JTAG and UART. Then:

```bash
cd artifacts
sha256sum -c SHA256SUMS
xsct run_on_zcu104.tcl
```

UART is `psu_uart_0` at 115200 8-N-1. Expected final line:

```text
BOARD ATTN_SCORE SOFTMAX ATTN_VALUE PASS
```

Physical board status remains pending until the user supplies UART output for
this BIT/ELF. This first-layer probe does not establish full-model inference.
