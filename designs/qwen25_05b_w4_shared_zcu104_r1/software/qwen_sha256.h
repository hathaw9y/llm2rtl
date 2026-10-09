#ifndef QWEN_SHA256_H
#define QWEN_SHA256_H
#include <stddef.h>
#include <stdint.h>
typedef struct { uint32_t h[8]; uint64_t bytes; unsigned used; uint8_t block[64]; } qwen_sha256;
void qwen_sha256_init(qwen_sha256 *s);
void qwen_sha256_update(qwen_sha256 *s,const void *data,size_t n);
void qwen_sha256_final(qwen_sha256 *s,uint8_t digest[32]);
#endif
