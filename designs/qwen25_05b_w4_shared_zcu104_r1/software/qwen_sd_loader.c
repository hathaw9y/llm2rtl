/* Read-only SD file transfer and SHA256. No model math or PL commands. */
#include "qwen_sd_loader.h"
#include "qwen_sha256.h"
#include "ff.h"
static FATFS fs;
static FIL file;
int qwen_sd_load(void *destination,size_t bytes,const uint8_t expected[32],void (*log)(const char *)){
 qwen_sha256 hash;uint8_t digest[32];size_t offset=0;unsigned progress=0;int status=0;
 log("SD_LOAD_BEGIN file=0:/QWEN.BIN\n");
 if(f_mount(&fs,"0:/",1)!=FR_OK){log("QWEN ERROR SD mount\n");return -1;}
 if(f_open(&file,"0:/QWEN.BIN",FA_READ)!=FR_OK){log("QWEN ERROR SD open QWEN.BIN\n");(void)f_mount(0,"0:/",0);return -2;}
 if((uint64_t)f_size(&file)!=(uint64_t)bytes){log("QWEN ERROR SD file size\n");status=-3;goto close;}
 qwen_sha256_init(&hash);
 while(offset<bytes){
  UINT request=(UINT)((bytes-offset)>1048576u?1048576u:bytes-offset),got=0;
  uint8_t *target=(uint8_t *)destination+offset;
  if(f_read(&file,target,request,&got)!=FR_OK || got!=request){log("QWEN ERROR SD read/short read\n");status=-4;goto close;}
  /* Hash destination DDR bytes after DMA completion, not an alternate buffer. */
  qwen_sha256_update(&hash,target,got);offset+=got;
  if(offset/(16u*1048576u)>progress){progress=(unsigned)(offset/(16u*1048576u));log("SD_LOAD_PROGRESS +16MiB\n");}
 }
 qwen_sha256_final(&hash,digest);
 for(unsigned i=0;i<32;i++)if(digest[i]!=expected[i]){log("QWEN ERROR SD SHA256 mismatch\n");status=-5;goto close;}
close:
 if(f_close(&file)!=FR_OK && status==0){log("QWEN ERROR SD close\n");status=-6;}
 if(f_mount(0,"0:/",0)!=FR_OK && status==0){log("QWEN ERROR SD unmount\n");status=-7;}
 if(status==0)log("SD_MODEL_SHA256_PASS\n");
 return status;
}
