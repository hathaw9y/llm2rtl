#!/usr/bin/env python3
"""Exercise real loader/SHA with host file-backed FatFs stubs; not SD hardware."""
import argparse,ctypes,hashlib,json,random,subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('out',type=Path);p.add_argument('--image',type=Path);a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 (out/'ff.h').write_text('''#include <stdint.h>
typedef unsigned UINT;
typedef struct {int unused;} FATFS;
typedef struct {uint64_t size;void *handle;} FIL;
#define FR_OK 0
#define FA_READ 1
#define f_size(f) ((f)->size)
int f_mount(FATFS*,const char*,int);
int f_open(FIL*,const char*,unsigned);
int f_read(FIL*,void*,UINT,UINT*);
int f_close(FIL*);
''')
 (out/'stub.c').write_text('''#include "ff.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "qwen_sd_loader.h"
static const char *path;static int fault;static unsigned closed,unmounted;
int f_mount(FATFS *fs,const char *p,int opt){(void)opt;if(strcmp(p,"0:/"))abort();if(!fs){unmounted++;return fault==7?1:0;}return fault==1?1:0;}
int f_open(FIL *f,const char *p,unsigned mode){if(strcmp(p,"0:/QWEN.BIN") || mode!=FA_READ)abort();if(fault==2)return 1;FILE *h=fopen(path,"rb");if(!h)return 1;fseek(h,0,SEEK_END);f->size=(uint64_t)ftell(h);rewind(h);f->handle=h;return 0;}
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
''')
 lib=out/'loader.so'
 subprocess.run(['gcc','-std=c11','-O2','-Wall','-Wextra','-Werror','-shared','-fPIC','-I'+str(out),'-I'+str(BASE/'software'),str(BASE/'software/qwen_sd_loader.c'),str(BASE/'software/qwen_sha256.c'),str(out/'stub.c'),'-o',str(lib)],check=True)
 dll=ctypes.CDLL(str(lib));dll.run.argtypes=[ctypes.c_char_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_int];dll.run.restype=ctypes.c_int
 results=[];rng=random.Random(29)
 for size in [0,1,55,56,63,64,65,511,512,65537,1048593]:
  data=rng.randbytes(size);file=out/'fixture.bin';file.write_bytes(data);digest=hashlib.sha256(data).digest()
  r=dll.run(str(file).encode(),size,digest,0);assert r==0,(size,r);results.append({'bytes':size,'status':'passed_SHA256_and_file_transfer'})
 file=out/'fixture.bin';data=file.read_bytes();size=len(data);digest=hashlib.sha256(data).digest()
 for fault,expected in [(1,-1),(2,-2),(4,-4),(6,-6),(7,-7),(8,-4)]:
  assert dll.run(str(file).encode(),size,digest,fault)==expected
  results.append({'fault':fault,'expected_status':expected,'passed':True})
 assert dll.run(str(file).encode(),size-1,digest,0)==-3
 assert dll.run(str(file).encode(),size,b'\0'*32,0)==-5
 if a.image:
  image=a.image.resolve();h=hashlib.sha256()
  with image.open('rb') as f:
   for block in iter(lambda:f.read(1048576),b''):h.update(block)
  assert dll.run(str(image).encode(),image.stat().st_size,h.digest(),0)==0
  results.append({'real_DDR_image_bytes':image.stat().st_size,'sha256':h.hexdigest(),'passed_host_loader':True})
 report={'status':'passed_host_file_backed_loader_integrity_and_error_tests','physical_SD_test':False,'tests':results,'additional_checks':['wrong file size rejected','wrong SHA256 rejected','destination tail guard retained','file closed and volume unmounted on errors'],'source_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in (BASE/'software').glob('qwen_s*') if f.is_file()}}
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()
