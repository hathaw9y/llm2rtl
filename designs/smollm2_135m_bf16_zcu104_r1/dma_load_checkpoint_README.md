# BF16 DDR → DMA_LOAD → bank verification

Run from the repository root with Vivado 2025.2 tools on PATH:

```sh
designs/smollm2_135m_bf16_zcu104_r1/scripts/run_dma_load_checkpoint_xsim.sh
```

The generator checks the pinned checkpoint vector hashes and creates a sparse
64-bit simulated DDR image. The self-checking XSIM test uses the real
`isa_command_dispatcher`, `smollm2_dma_control_fabric_wide`, DMA bridge,
bank subsystem, and 128-bit command records. It models the external AXI
DataMover and DDR at the DataMover stream interface. It verifies command
addresses and byte counts, status-gated bank release, and every 128-bit bank
word against the source DDR data:

| Chunk | ISA LOAD | Bytes | Bank words checked |
| --- | --- | ---: | ---: |
| Prefill | activation → B0 | 36,864 | 2,304 |
| Prefill | layer-0 q_proj weights → B3 | 18,432 | 1,152 |
| Decode | activation → B0 | 1,152 | 72 |

The decode chunk also rereads all 1,152 B3 weight words to verify retention
across END/DONE. A testbench RMSNORM response holds legal bank read roles 6
and 7 while the test reads back data; it performs no RMSNORM calculation and
does not validate that executor. The script reports
`PASS smollm2_dma_load_checkpoint` only after all comparisons succeed.

The current ISA permits DMA_LOAD to B0 and B3, but B2 is produced by PL
RMSNORM and cannot be targeted by DMA_LOAD. This test does not exercise AXI
DataMover IP, physical DDR, board timing, GEMM, or a physical ZCU104.
