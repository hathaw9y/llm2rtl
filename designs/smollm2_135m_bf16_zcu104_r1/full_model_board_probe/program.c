#include <stdint.h>
#include "program.h"
#include "address_map.h"

enum { OP_END=0, OP_LOAD=1, OP_STORE=2, OP_GEMM=3, OP_RMS=4,
       OP_ROPE=5, OP_SCORE=6, OP_SOFTMAX=7, OP_VALUE=8,
       OP_ADD=9, OP_SILU=10, OP_FENCE=11, OP_GEMM_TILES=12 };
typedef struct { model_emit_fn emit; void *opaque; } emitter;
static int record(emitter *e, unsigned op, unsigned b0, unsigned b1,
                  unsigned b2, __uint128_t payload)
{
    __uint128_t x=((__uint128_t)op<<124)|((__uint128_t)b0<<120)|
                  ((__uint128_t)b1<<116)|((__uint128_t)b2<<112)|payload;
    uint32_t words[4];
    for(unsigned i=0;i<4;++i) words[i]=(uint32_t)(x>>(32u*i));
    return e->emit(e->opaque,words);
}
static int dma(emitter *e,unsigned op,unsigned bank,uint32_t addr,
               uint32_t bytes,uint32_t offset,uint32_t aux)
{
    if((addr&15u)||(bytes&15u)||bytes==0u||bytes>=(1u<<23)||
       (offset&15u)||aux>=(1u<<25)) return -1;
    return record(e,op,bank,0,0,((__uint128_t)offset<<80)|
                  ((__uint128_t)bytes<<57)|((__uint128_t)addr<<25)|aux);
}
static int vector3(emitter *e,unsigned op,unsigned b0,unsigned b1,
                   unsigned b2,unsigned rows)
{
    return record(e,op,b0,b1,b2,rows);
}
static int rope(emitter *e,unsigned bank,unsigned rows)
{
    return record(e,OP_ROPE,bank,7,0,rows);
}
static int attention(emitter *e,unsigned op,unsigned b0,unsigned b1,
                     unsigned b2,unsigned start,unsigned rows,unsigned len)
{
    __uint128_t payload=((__uint128_t)start<<17)|((__uint128_t)rows<<11)|len;
    return record(e,op,b0,b1,b2,payload);
}
#ifndef USE_GEMM_TILES
static int gemm(emitter *e,unsigned src,unsigned dst,unsigned n,
                unsigned n_total,unsigned m_start,unsigned m_count,unsigned k)
{
    __uint128_t payload=n;
    payload=(payload<<16)|n_total;
    payload=(payload<<6)|m_start;
    payload=(payload<<6)|m_count;
    payload=(payload<<11)|k;
    payload=(payload<<8)|192u;
    return record(e,OP_GEMM,src,3,dst,payload);
}
#endif
static int gemm_tiles(emitter *e,uint32_t weight_base,unsigned src,
                      unsigned dst,unsigned out,unsigned k,
                      unsigned m_start,unsigned m_count)
{
#ifdef USE_GEMM_TILES
    // The PL expands this descriptor into the same DMA_LOAD/GEMM tile pairs.
    // Keep the old expansion available for the original routed bitstream.
    if(!out||out>49152u||!k||k>2047u||!m_count||m_count>32u||
       m_start+m_count>32u||(weight_base&15u)) return -1;
    __uint128_t payload=((__uint128_t)weight_base<<80)|
        ((__uint128_t)out<<64)|((__uint128_t)k<<53)|
        ((__uint128_t)m_start<<47)|((__uint128_t)m_count<<41)|
        ((__uint128_t)192u<<33);
    return record(e,OP_GEMM_TILES,src,3u,dst,payload);
#else
    for(unsigned n=0;n<out;n+=192u){
        if(dma(e,OP_LOAD,3,weight_base+n*k*2u,192u*k*2u,0,0)) return -1;
        if(gemm(e,src,dst,n,out,m_start,m_count,k)) return -1;
    }
    return 0;
#endif
}
int smollm2_emit_block_with_logits(const uint16_t *tokens,unsigned rows,
                       unsigned start,int produce_logits,model_emit_fn send,
                       model_layer_fn layer_done,void *opaque)
{
    emitter e={send,opaque};
    if(!tokens||!send||!layer_done||rows<1u||rows>32u||start+rows>1024u) return -1;
    for(unsigned row=0;row<rows;++row){
        if(tokens[row]>=49152u) return -1;
        if(dma(&e,OP_LOAD,0,MODEL_EMBEDDING_BASE+(uint32_t)tokens[row]*1152u,
               1152u,row*1152u,(rows<<6)|row)) return -1;
    }
    if(dma(&e,OP_LOAD,7,MODEL_ROPE_BASE+start*128u,rows*128u,0,0)) return -1;
    for(unsigned layer=0;layer<30u;++layer){
        const uint32_t *w=layer_weight_base[layer];
        if(dma(&e,OP_LOAD,3,w[W_INPUT_NORM],1152u,0,0)) return -1;
        if(vector3(&e,OP_RMS,0,3,2,rows)) return -1;
        if(gemm_tiles(&e,w[W_Q],2,4,576,576,0,rows)) return -1;
        if(gemm_tiles(&e,w[W_K],2,5,192,576,0,rows)) return -1;
        if(gemm_tiles(&e,w[W_V],2,6,192,576,0,rows)) return -1;
        if(rope(&e,4,rows)||rope(&e,5,rows)) return -1;
        if(dma(&e,OP_STORE,5,layer_kv_base[layer][0]+start*384u,
               rows*384u,0,0)) return -1;
        if(dma(&e,OP_STORE,6,layer_kv_base[layer][1]+start*384u,
               rows*384u,0,0)) return -1;
        if(record(&e,OP_FENCE,0,0,0,0)) return -1;
        if(dma(&e,OP_LOAD,8,layer_kv_base[layer][0],(start+rows)*384u,0,0)) return -1;
        if(dma(&e,OP_LOAD,9,layer_kv_base[layer][1],(start+rows)*384u,0,0)) return -1;
        if(attention(&e,OP_SCORE,4,8,10,start,rows,start+rows)) return -1;
        if(attention(&e,OP_SOFTMAX,10,0,0,start,rows,start+rows)) return -1;
        if(attention(&e,OP_VALUE,10,9,11,start,rows,start+rows)) return -1;
        if(gemm_tiles(&e,w[W_O],11,1,576,576,0,rows)) return -1;
        if(vector3(&e,OP_ADD,0,1,5,rows)) return -1;
        if(dma(&e,OP_LOAD,3,w[W_POST_NORM],1152u,0,0)) return -1;
        if(vector3(&e,OP_RMS,5,3,2,rows)) return -1;
        if(gemm_tiles(&e,w[W_GATE],2,8,1536,576,0,rows)) return -1;
        if(gemm_tiles(&e,w[W_UP],2,9,1536,576,0,rows)) return -1;
        if(vector3(&e,OP_SILU,8,9,10,rows)) return -1;
        if(gemm_tiles(&e,w[W_DOWN],10,1,576,1536,0,rows)) return -1;
        if(vector3(&e,OP_ADD,5,1,0,rows)) return -1;
        if(layer_done(opaque,layer)) return -1;
    }
    if(produce_logits){
        if(dma(&e,OP_LOAD,3,MODEL_FINAL_NORM,1152u,0,0)) return -1;
        if(vector3(&e,OP_RMS,0,3,2,rows)) return -1;
        if(gemm_tiles(&e,MODEL_EMBEDDING_BASE,2,12,49152,576,rows-1,1)) return -1;
        if(dma(&e,OP_STORE,12,MODEL_LOGITS_BASE,49152u*2u,0,0)) return -1;
        if(record(&e,OP_FENCE,0,0,0,0)) return -1;
    }
    return 0;
}
int smollm2_emit_block(const uint16_t *tokens,unsigned rows,unsigned start,
                       model_emit_fn send,model_layer_fn layer_done,void *opaque)
{
    return smollm2_emit_block_with_logits(tokens,rows,start,1,send,
                                         layer_done,opaque);
}
