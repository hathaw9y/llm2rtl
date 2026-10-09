#include <stdint.h>
#include <stdio.h>
#include "program.h"

static int emit(void *opaque, const uint32_t words[4])
{
    (void)opaque;
    printf("%08x%08x%08x%08x\n", words[3], words[2], words[1], words[0]);
    return 0;
}
static int layer_done(void *opaque, unsigned layer)
{
    (void)opaque;
    (void)layer;
    return 0;
}
int main(void)
{
    uint16_t ids[41];
    for (unsigned i = 0; i < 41u; ++i)
        ids[i] = (uint16_t)((i * 17u + 11u) % 49152u);
    puts("BEGIN 0 32 0");
    if (smollm2_emit_block_with_logits(ids, 32u, 0u, 0, emit, layer_done, 0))
        return 1;
    puts("BEGIN 32 8 1");
    if (smollm2_emit_block_with_logits(ids + 32, 8u, 32u, 1,
                                      emit, layer_done, 0)) return 2;
    puts("BEGIN 40 1 1");
    if (smollm2_emit_block_with_logits(ids + 40, 1u, 40u, 1,
                                      emit, layer_done, 0)) return 3;
    return 0;
}
