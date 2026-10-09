#include "qwen_isa.h"
#include <stdio.h>
#include <stdlib.h>
#include "memory.h"
static int submit(void *ctx,const uint8_t *data,size_t records){(void)ctx;uint32_t n=(uint32_t)records;return fwrite(&n,4,1,stdout)==1 && fwrite(data,32,records,stdout)==records?0:-10;}
static qwen_compiler compiler;
int main(int argc,char **argv){if(argc!=4)return 1;unsigned n=(unsigned)atoi(argv[1]),prefix=(unsigned)atoi(argv[2]);int decode=atoi(argv[3]);uint32_t t[512];if(n>512)return 2;for(unsigned i=0;i<n;i++)t[i]=(uint32_t[]){9707,11,151643}[i%3];qwen_compiler_init(&compiler,&memory,submit,0);return qwen_compile(&compiler,t,n,(uint16_t)prefix,decode)?3:0;}
