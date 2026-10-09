#include <stdio.h>
#include <stdint.h>
#include "program.h"
#ifdef USE_GEMM_TILES
#define PREFILL_TRACE "trace_prefill_tiled.hex"
#define DECODE_TRACE "trace_decode_tiled.hex"
#else
#define PREFILL_TRACE "trace_prefill.hex"
#define DECODE_TRACE "trace_decode.hex"
#endif
typedef struct { FILE *file; unsigned pending, chunks; uint32_t seen; } trace_context;
static int emit(void *opaque,const uint32_t words[4])
{
    trace_context *ctx=(trace_context *)opaque;
    uint32_t bit=smollm2_probe_counter_bit(words);
    if(ctx->seen&bit){ctx->pending=0;ctx->seen=0;ctx->chunks++;}
    fprintf(ctx->file,"%08x%08x%08x%08x\n",words[3],words[2],words[1],words[0]);
    ctx->seen|=bit;
    if(++ctx->pending==15u){ctx->pending=0;ctx->seen=0;ctx->chunks++;}
    return 0;
}
static int layer_done(void *opaque,unsigned layer)
{
    trace_context *ctx=(trace_context *)opaque;
    (void)layer;
    if(ctx->pending){ctx->pending=0;ctx->seen=0;ctx->chunks++;}
    return 0;
}
int main(void)
{
    uint16_t prefill[32],decode[1]={555};
    for(unsigned i=0;i<32;++i) prefill[i]=(uint16_t)(i*17u+11u);
    trace_context ctx={fopen(PREFILL_TRACE,"w"),0,0,0};
    if(!ctx.file) return 1;
    if(smollm2_emit_block(prefill,32,0,emit,layer_done,&ctx)) return 2;
    if(ctx.pending)ctx.chunks++;
    fclose(ctx.file);
    printf("prefill chunks=%u\n",ctx.chunks);
    ctx=(trace_context){fopen(DECODE_TRACE,"w"),0,0,0};
    if(!ctx.file) return 3;
    if(smollm2_emit_block(decode,1,32,emit,layer_done,&ctx)) return 4;
    if(ctx.pending)ctx.chunks++;
    fclose(ctx.file);
    printf("decode chunks=%u\n",ctx.chunks);
    return 0;
}
