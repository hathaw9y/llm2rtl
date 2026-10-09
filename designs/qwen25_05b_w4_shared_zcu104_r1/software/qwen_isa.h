#ifndef QWEN_ISA_H
#define QWEN_ISA_H
#include <stdint.h>
#include <stddef.h>
/* Addresses and dimensions only. Quantized tensor data is never evaluated here. */
typedef struct {uint32_t codes,scales,bias;uint32_t n,k;} qwen_weight;
typedef struct {qwen_weight q,k,v,o,gate,up,down;uint32_t norm1,norm2,kv[2][2];} qwen_layer;
typedef struct {qwen_weight embedding;qwen_layer layers[24];uint32_t embedding_codes,embedding_scales,rope,norm,logits;} qwen_memory;
typedef int (*qwen_submit)(void *context,const uint8_t *image,size_t records);
typedef struct {
 uint8_t image[1024][32];uint32_t stores[1023][2];uint16_t count,store_count,serial;
 int error;qwen_submit submit;void *context;const qwen_memory *memory;
 uint64_t commands,chunks;
} qwen_compiler;
void qwen_compiler_init(qwen_compiler *,const qwen_memory *,qwen_submit,void *);
/* decode==0 requires prefix0 and1..512 input IDs. decode==1 requires one ID.
   submit must wait for END/DONE, check error, then permit next image publication.
   Caller commits cache length only after qwen_compile returns0. No reset at END. */
int qwen_compile(qwen_compiler *,const uint32_t *tokens,size_t count,uint16_t prefix,int decode);
#endif
