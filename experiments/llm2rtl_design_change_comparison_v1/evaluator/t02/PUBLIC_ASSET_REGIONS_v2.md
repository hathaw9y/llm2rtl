# T02 static-image region names (v2 supplement)

This naming specification supplements the existing T02 image-map interface. It does not change the design task or the original evaluator v1 bundle.

Use these stable logical names in the `regions` entries of `t02_asset_map.json`:

| Logical asset | Name |
| --- | --- |
| Entire token embedding table | `embedding` |
| Input layer norm for layer L | `layer.LL.input_layernorm` |
| Post attention layer norm for layer L | `layer.LL.post_attention_layernorm` |
| Dense tile for layer L, projection P, first output channel S | `layer.LL.P.nSSSSS` |
| Final norm | `final.norm` |
| Entire RoPE table | `rope` |
| LM head tile starting at output channel S | `lm_head.nSSSSS` |

`LL` is a decimal layer index padded to two digits; `SSSSS` is a decimal first output channel padded to five digits. `P` is one of `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`. For example, `layer.00.q_proj.n00192` identifies the Q projection tile in layer 0 that starts at output channel 192.

Offsets are byte offsets relative to the image file start. Keep `kind: raw` for embedding, both layer norms, final norm and RoPE; keep `kind: dense` plus actual `n_tile` and `k` for each dense tile. Each entry describes the actual image interval used by the published address map and DMA load path. Include both embedding and LM head logical entries even when their original source representation shares bytes.

A candidate's existing published map may use other names. The evaluator can normalize names from explicit semantic identity (`layer`, projection/tensor name, first output channel), the published address map and the actual command-generation source. Naming differences alone do not invalidate a candidate when identity is unambiguous. If names cannot be normalized without guessing, the evaluator records an interface ambiguity separately from packing correctness.
