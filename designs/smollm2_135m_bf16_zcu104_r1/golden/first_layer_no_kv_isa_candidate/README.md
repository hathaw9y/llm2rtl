# First-layer ISA candidate without KV-cache traffic

This candidate starts with token IDs and the pinned checkpoint weights in DDR. The PS builds 128-bit instruction records from IDs, dimensions, and DDR addresses; the Python interpreter executes all tensor operations. The path is layer 0 from embedding through the final FFN residual output. It computes K and V on PL from the current input, keeps them in B8/B9 for attention, and performs no `DMA_STORE`, `FENCE`, or KV-cache reload.

## Bank schedule

| Stage | ISA sequence | Output |
| --- | --- | --- |
| Input | `DMA_LOAD` embedding rows B0; RoPE coefficients B7 | B0, B7 |
| Attention projections | `RMSNORM B0,B3→B2`; tiled `GEMM` Q→B4, K→B8, V→B9 | B4, B8, B9 |
| Attention | `ROPE B4,B7`; `ROPE B8,B7`; `ATTN_SCORE B4,B8→B10`; `SOFTMAX B10`; `ATTN_VALUE B10,B9→B11` | B11 |
| Attention residual | tiled `GEMM B11,B3→B1`; `ADD B0,B1→B5` | B5 |
| FFN | `RMSNORM B5,B3→B2`; tiled `GEMM` gate→B8 and up→B9; `SILU_MUL B8,B9→B10`; tiled down `GEMM B10,B3→B1`; `ADD B5,B1→B0` | B0 |

The current GPIO board shell holds 16 command records, so the program is split into chunks of at most 15 operations plus `END`. Prefill32 uses 106 records in 7 chunks; cold single-token inference uses 73 records in 5 chunks. `END/DONE` drains outstanding work; the interpreter preserves bank contents and partial tensor progress between chunks. Each 128-bit record round-trips through the current wire encoder and decoder.

With the pinned Hugging Face eager BF16 reference, the functional interpreter matches the complete layer-0 output bit for bit for prefill32 `[32,576]` and a one-token cold start `[1,576]`. The latter is **not** decode after an existing prefix: that requires KV-cache history and is outside this candidate.

## RTL and board status

The dispatcher, bank router, and RoPE executor now permit K RoPE on B8. The
new board wrapper enables the B8 RoPE tap and the final ADD B0 tap. The
standalone B8 RoPE golden comparison passed for prefill32, one token, and
the tail positions. The new board bitstream and physical comparison are
tracked separately in `first_layer_no_kv_board_probe`.

No new opcode, `DMA_STORE`, or `FENCE` is required for this no-cache,
position-zero path. Interpreter success and RTL legality are **not** a board
PASS. See `result.json` and the per-case `commands.hex`/`commands.json` files.
