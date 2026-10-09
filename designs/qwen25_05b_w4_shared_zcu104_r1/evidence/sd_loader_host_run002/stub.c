#include "ff.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "qwen_sd_loader.h"
static const char *path;static int fault;static unsigned closed,unmounted;
int f_mount(FATFS *fs,const char *p,int opt){(void)opt;if(strcmp(p,"0:/"))abort();if(!fs){unmounted++;return fault==7?1:0;}return fault==1?1:0;}
int f_open(FIL *f,const char *p,unsigned mode){if(strcmp(p,"0:/MODEL.BIN") || mode!=FA_READ)abort();if(fault==2)return 1;FILE *h=fopen(path,"rb");if(!h)return 1;fseek(h,0,SEEK_END);f->size=(uint64_t)ftell(h);rewind(h);f->handle=h;return 0;}
int f_read(FIL *f,void *p,UINT request,UINT *got){if(fault==4)return 1;*got=(UINT)fread(p,1,request,(FILE*)f->handle);if(fault==8 && *got)(*got)--;return 0;}
int f_close(FIL *f){closed++;fclose((FILE*)f->handle);return fault==6?1:0;}
static void logline(const char *s){(void)s;}
int run(const char *filename,size_t size,const unsigned char *digest,int injected){
path=filename;fault=injected;closed=unmounted=0;
unsigned char *mem=malloc(size+32);if(!mem)abort();memset(mem+size,0xA5,32);
int r=qwen_sd_load(mem,size,digest,logline);
for(unsigned i=0;i<32;i++)if(mem[size+i]!=0xA5)abort();
if(fault!=1 && !unmounted){abort();}
if(fault!=1 && fault!=2 && !closed){abort();}
free(mem);return r;
}
