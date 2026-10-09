#include <stdio.h>
#include <stdlib.h>
#include "program.c"
static int seen;
static int capture(void *p,const uint32_t w[4]) { (void)p; seen++; printf("%08x%08x%08x%08x\n",w[3],w[2],w[1],w[0]); return 0; }
static int boundary(void *p,unsigned layer) { (void)p; printf("L%u\n",layer); return 0; }
int main(int argc,char **argv) {
 if(argc!=4)return 2;
 unsigned count=strtoul(argv[1],0,0),start=strtoul(argv[2],0,0),mode=strtoul(argv[3],0,0);
 emitter e={capture,0}; int rc;
 if(mode==0) { uint16_t tokens[32]={0}; rc=smollm2_emit_block(tokens,count,0,capture,boundary,0); }
 else rc=gemm_tiles(&e,MODEL_EMBEDDING_BASE,2,4,384,16,start,count);
 fprintf(stderr,"RC=%d SEEN=%d\n",rc,seen); return 0;
}
