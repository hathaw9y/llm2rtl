/* Runtime performs ISA control and byte transfers only. No tensor arithmetic. */
#include "qwen_isa.h"
#include "qwen_memory.h"
#ifdef QWEN_SD_LOAD
#include "qwen_sd_loader.h"
#include "qwen_sd_image.h"
#endif
#define CONTROL_BASE 0xA0010000u
#define COMMAND_BASE 0xA0000000u
#define UART_BASE 0xFF010000u
static qwen_compiler compiler;
static uint32_t cache_length;
static volatile uint32_t *reg(uint32_t address){return (volatile uint32_t *)(uintptr_t)address;}
static void barrier(void){__asm__ volatile("dsb sy":::"memory");}
void *memset(void *dst,int value,size_t n){uint8_t *p=dst;while(n--)*p++=(uint8_t)value;return dst;}
void *memcpy(void *dst,const void *src,size_t n){uint8_t *d=dst;const uint8_t *s=src;while(n--)*d++=*s++;return dst;}
#ifdef QWEN_SD_LOAD
void *memmove(void *dst,const void *src,size_t n){uint8_t *d=dst;const uint8_t *s=src;if((uintptr_t)d<(uintptr_t)s){while(n--)*d++=*s++;}else{d+=n;s+=n;while(n--)*--d=*--s;}return dst;}
int memcmp(const void *a,const void *b,size_t n){const uint8_t *x=a,*y=b;while(n--){if(*x!=*y)return (int)*x-(int)*y;x++;y++;}return 0;}
char *strchr(const char *s,int c){for(;;s++){if((uint8_t)*s==(uint8_t)c)return (char *)s;if(!*s)return 0;}}
size_t strnlen(const char *s,size_t max){size_t n=0;while(n<max && s[n])n++;return n;}
char *strncat(char *dst,const char *src,size_t max){char *p=dst;while(*p)p++;while(max-- && *src)*p++=*src++;*p=0;return dst;}
#endif
static void text(const char *s){while(*s){if(*s=='\n'){while(*reg(UART_BASE+0x2c)&16u){}*reg(UART_BASE+0x30)='\r';}while(*reg(UART_BASE+0x2c)&16u){}*reg(UART_BASE+0x30)=(uint8_t)*s++;}}
static void number(uint64_t x){char s[21];unsigned i=0;do{s[i++]=(char)('0'+x%10);x/=10;}while(x);while(i){char t[2]={s[--i],0};text(t);}}
static int fail(uint32_t status){text("QWEN ERROR status=");number(status);text("\nCache invalid; coordinated reset and replay required.\n");cache_length=0;return -4;}
static int submit(void *unused,const uint8_t *image,size_t records){
 (void)unused;uint32_t status=*reg(CONTROL_BASE+4);
 if((status&13u) || records==0 || records>1024)return fail(status);
 volatile uint32_t *destination=reg(COMMAND_BASE);const uint32_t *source=(const uint32_t *)(const void *)image;
 for(size_t i=0;i<records*8;i++)destination[i]=source[i];
 /* Cache/MMU are disabled by startup. DSB orders complete image before START. */
 barrier();*reg(CONTROL_BASE)=1;barrier();
 uint64_t attempts=0;
 do{status=*reg(CONTROL_BASE+4);if(status&4u)return fail(status);if(++attempts>1000000000ull)return fail(status);}while(!(status&2u));
 if(status&1u)return fail(status);
 return 0;
}
static void copy_bytes(uint32_t dst,uint32_t src,uint32_t bytes){volatile uint8_t *d=(volatile uint8_t *)(uintptr_t)dst;const volatile uint8_t *s=(const volatile uint8_t *)(uintptr_t)src;while(bytes--)*d++=*s++;barrier();}
static void snapshot(uint32_t logits_dst,uint32_t kv_dst,uint32_t length){
 copy_bytes(logits_dst,memory.logits,151936u*2u);
 for(unsigned l=0;l<24;l++)for(unsigned kind=0;kind<2;kind++)for(unsigned head=0;head<2;head++){
  copy_bytes(kv_dst,memory.layers[l].kv[kind][head],length*128u);kv_dst+=length*128u;
 }
}
static void report(const char *phase){
 uint32_t lo=*reg(CONTROL_BASE+8),hi=*reg(CONTROL_BASE+12);
 text(phase);text(" DONE commands=");number(compiler.commands);text(" chunks=");number(compiler.chunks);text(" PL_active_cycles=");number(((uint64_t)hi<<32)|lo);text(" cache_length=");number(cache_length);text("\n");
}
int main(void){
 text("QWEN shared W4 ISA baremetal r1 / no runtime tensor math\n");
 if(*reg(CONTROL_BASE+0x18)!=0x51574e31u){text("wrong accelerator profile\n");return 1;}
 *reg(CONTROL_BASE)=2;barrier();while(*reg(CONTROL_BASE+4)&8u){}
#ifdef QWEN_SD_LOAD
 /* START is forbidden until SD size, read and full-image SHA256 pass. */
 if(qwen_sd_load((void *)(uintptr_t)0x10000000u,QWEN_SD_IMAGE_BYTES,qwen_sd_expected_sha256,text))return 4;
 barrier();
#endif
 qwen_compiler_init(&compiler,&memory,submit,0);cache_length=0;
 const uint32_t prefill_ids[]={9707,11};const uint32_t decode_ids[]={151643};
 if(qwen_compile(&compiler,prefill_ids,2,0,0))return 2;
 cache_length=2;snapshot(0x08000000u,0x08050000u,cache_length);report("prefill2");
 if(qwen_compile(&compiler,decode_ids,1,(uint16_t)cache_length,1))return 3;
 cache_length++;snapshot(0x08100000u,0x08150000u,cache_length);report("decode1");
 text("HANDOFF_DONE. Dump prefill logits @0x08000000, KV @0x08050000; decode logits @0x08100000, KV @0x08150000.\nCompare host golden bytes; this log alone is not model/board acceptance.\n");
 return 0;
}
