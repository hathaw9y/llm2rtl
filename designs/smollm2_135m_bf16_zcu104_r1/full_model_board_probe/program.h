#ifndef SMOLLM2_FULL_MODEL_PROGRAM_H
#define SMOLLM2_FULL_MODEL_PROGRAM_H
#include <stdint.h>
typedef int (*model_emit_fn)(void *opaque, const uint32_t words[4]);
typedef int (*model_layer_fn)(void *opaque, unsigned layer);
/* The board probe checks write addresses with counters reset at each END.
 * Keep repeated probe kernels in separate command BRAM fragments. */
static inline uint32_t smollm2_probe_counter_bit(const uint32_t words[4])
{
#ifdef USE_GEMM_TILES
    unsigned op=words[3]>>28;
    unsigned bank=(words[3]>>24)&15u;
    switch(op){
    case 4u: return 1u<<0;  /* RMSNORM */
    case 5u: return bank==4u?(1u<<1):(1u<<2); /* Q/K RoPE */
    case 6u: return 1u<<3;  /* score */
    case 7u: return 1u<<4;  /* softmax */
    case 8u: return 1u<<5;  /* attention value */
    case 9u: return 1u<<6;  /* both ADD destinations share one counter */
    case 10u:return 1u<<7;  /* SiLU */
    default: return 0u;
    }
#else
    (void)words;
    return 0u;
#endif
}
/* PS constructs ISA from token IDs, absolute position, and static DDR address map. */
int smollm2_emit_block(const uint16_t *tokens, unsigned rows, unsigned start,
                       model_emit_fn emit, model_layer_fn layer_done, void *opaque);
/* Intermediate prefill chunks can omit the final norm/lm_head/logits store. */
int smollm2_emit_block_with_logits(const uint16_t *tokens, unsigned rows,
                       unsigned start, int produce_logits, model_emit_fn emit,
                       model_layer_fn layer_done, void *opaque);
#endif
