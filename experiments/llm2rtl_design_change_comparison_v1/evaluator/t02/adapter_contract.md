# T02 evaluator interface and participant prompt requirements

Candidate software exposes `t02_adapter.py` at `--candidate-root`. It reads one JSON request from stdin, writes one JSON object to stdout, and exits. Diagnostics go to stderr. It calls the candidate's actual offline asset packer, interpreter physical dense-load implementation, and PS DMA / GEMM_TILES command generation. It must not reimplement these merely for the evaluator. Source review and full-model gates verify that provenance. This adapter adds observability, not a new required design architecture.

The `dense_tile` request contains `baseline_mode`, `n`, `k`, original `rows` of unsigned BF16 words, independently supplied `physical_bits`, `probe_k`, `byte_base`, and `tile_index`. Return:

* `packed_bits`: offline packer output for original rows, unsigned 16-bit words.
* `unpacked_rows`: inverse asset packing result.
* `interpreted_rows`: semantic rows produced by the interpreter's actual physical load of supplied `physical_bits` (do not substitute original `rows`).
* `layout_id`: `dense_nk_bf16` for baseline, `dense_k16_n_lane_bf16` for target. Other existing manifest names may be normalized to these strings by the adapter with explicit mapping.
* `sha256`: actual SHA256 of packed BF16 words serialized little endian.
* `dma_offset_bytes`: `byte_base + tile_index*n*k*2` for this equal-tile probe.
* `dma_btt` and `gemm_tiles_weight_step_bytes`: both `n*k*2`.

The `embedding_lm_head` request contains `embedding_rows`, `baseline_mode`, `byte_base`, `reserved_end`. Return `embedding_lookup_rows` from actual embedding lookup, `lm_head_physical_bits` from actual dense asset generator, `lm_head_interpreted_rows` from actual physical dense-load interpreter, `embedding_byte_base`, and `lm_head_byte_base` from actual address-map allocation. The finite fixtures use a tiny synthetic vocabulary; the production path must remain valid for 49152 rows and K=576.

Participant task wording to freeze before trials:

> Keep token embedding lookup row-major and bit-exact. Pack every dense N tile, including LM head, once into K16-block order: `((k//16)*N_tile+n)*16+k%16`. The existing row-major embedding/LM-head physical alias cannot represent both layouts for K>16 and N_tile>1: provide a separate packed LM-head representation within reserved DDR bounds, or an equally correct explicitly documented transport arrangement. Update offline asset generation, physical DDR/interpreter loading, manifest layout identifier and hash, address map, and PS dense DMA / GEMM_TILES weight bases and byte counts consistently. Retain attention runtime layouts. Norm/RoPE assets remain bit-exact. No PS tensor computation is permitted.

No element padding is allowed in this scope. Tail tiles use their actual N_tile in the formula; a final tail is not indexed with nominal 192. Dense operand bits and arithmetic order are unchanged. BTT stays `2*N_tile*K`; contiguous tile offset increments remain equal to tile packed size. A shifted LM-head allocation requires updating later regions/DDR bounds and corresponding address-map/model-image assertions.

The software adapter gate must be accompanied by review/build of changed PS C, image generator and address map. Run actual asset generation, compare every dense packed tile and its inverse to original BF16 tensor bits, compare embedding/norm/RoPE bytes, and validate all static-image address intervals and generated DMA ranges. A JSON adapter result alone is not asset or PS integration signoff.

Run evaluator with `--candidate-root ROOT --out OUT --rtl`; `--baseline-mode` selects old physical fixtures. `--split public|hidden|all` selects fixtures. Hidden fixture seeds and evaluator code must be omitted from participant resources; fixtures are evaluator owned. Public and hidden suites both include randomized distinctive finite words, and separate arbitrary 16-bit words including NaN payloads for packing preservation. One-hot activation rows make expected dense BF16 output exactly equal to the original selected weight word without relying on candidate arithmetic code. This does not stress general dense rounding/overflow.

`--oracle-self-test` enables evaluator calibration. With target mode it creates an evaluator-owned copy of baseline dense RTL with the minimal new base-address expression, solely as a positive control. `--mutation old-address` retains the old RTL expression; `--mutation double-pack` applies the target permutation twice to physical fixtures. These are evaluator probes, never comparison participants. Production source is never edited.

Current native RTL bench binds production `smollm2_gemm_systolic_wide_executor` through its original ports, including paired 128-bit memory reads. Dense mode of the shared production array is covered; attention mode and board-fabric integration require separate gates. No synthesis/board PASS is inferred.

The executable `scripts/t02_audit_assets.py` audits real images. It requires evaluator-owned immutable `--reference-image` and `--reference-map` alongside `--candidate-root`, `--out`, optional `--baseline-mode`. The candidate supplies `t02_asset_map.json` with `image` (relative file path), `image_sha256`, `layout_id`, `ddr_base`, `reserved_end`, and `regions`. Each region has `name`, `kind`, `offset_bytes`, `size_bytes`; dense regions additionally have `n_tile`, `k`. The evaluator reference map uses the same logical names and original file offsets. Norm, RoPE and embedding are raw regions; each dense tile is separate. Reference LM-head regions can overlap row-major embedding. Target regions cannot overlap. The reference map must cover all original static image bytes, so omitted regions fail. Target dense values are packed from original image bytes, not candidate adapter output. Before freeze the evaluator owner must produce and audit the full baseline reference map and run this gate against generated candidate assets; current calibration exercises synthetic maps only.
