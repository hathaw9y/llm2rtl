#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"

#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u
#define KV_WORDS (1024u*24u)
static uint32_t kv_key_words[KV_WORDS][4] __attribute__((aligned(64)));
static uint32_t kv_value_words[KV_WORDS][4] __attribute__((aligned(64)));
static uint16_t layer_output_scratch[32u*576u] __attribute__((aligned(64)));
static const uint32_t zero[4] = {0,0,0,0};
static unsigned host_seq;

static int host_op(unsigned op,unsigned bank,unsigned addr,const uint32_t data[4],uint32_t *response)
{
    uint32_t status=0;
    unsigned poll;
    Xil_Out32(GPIO_LO,data[0]); Xil_Out32(GPIO_LO+8u,data[1]);
    Xil_Out32(GPIO_HI,data[2]); Xil_Out32(GPIO_HI+8u,data[3]);
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq^=1u;
    Xil_Out32(GPIO_CTL,(host_seq<<31)|(op<<28)|(bank<<24)|addr);
    for(poll=0;poll<POLL_LIMIT;++poll){
        status=Xil_In32(GPIO_CTL+8u);
        if(((status>>31)&1u)==host_seq && ((status>>30)&1u)==0u) break;
    }
    if(response) *response=status;
    if(poll==POLL_LIMIT || ((status>>28)&1u)){
        xil_printf("HOST FAIL op=%u bank=%u addr=%u status=%08x\r\n",op,bank,addr,(unsigned)status);
        return -1;
    }
    return 0;
}
static int wait_done(const char *name,unsigned chunk)
{
    for(unsigned poll=0;poll<POLL_LIMIT;++poll){
        uint32_t status=Xil_In32(GPIO_CTL+8u);
        if((status>>28)&1u){
            xil_printf("%s chunk=%u ERROR status=%08x\r\n",name,chunk,(unsigned)status);
            return -1;
        }
        if((status>>27)&1u) return 0;
    }
    xil_printf("%s chunk=%u TIMEOUT\r\n",name,chunk);
    return -1;
}
static float bf16_float(uint16_t bits)
{
    union {uint32_t u;float f;} v;
    v.u=(uint32_t)bits<<16;
    return v.f;
}
static unsigned bf16_ulp(uint16_t a,uint16_t b)
{
    unsigned x=a&0x8000u ? 0xffffu-a : a+0x8000u;
    unsigned y=b&0x8000u ? 0xffffu-b : b+0x8000u;
    return x>y ? x-y : y-x;
}
static const uint32_t (*source_base(unsigned source))[4]
{
    switch(source){
    case 0: return kv_prefill32_embedding_words;
    case 1: return kv_prefill32_coeff_words;
    case 2: return kv_decode1_embedding_words;
    case 3: return kv_decode1_coeff_words;
    case 4: return weight_words;
    case 5: return (const uint32_t (*)[4])kv_key_words;
    case 6: return (const uint32_t (*)[4])kv_value_words;
    default: return 0;
    }
}
static int compare_values(const char *name,const uint16_t *got,
                          const uint16_t *expected,unsigned count)
{
    unsigned mismatches=0,max_ulp=0,max_abs_micro=0;
    double sum_sq=0.0;
    for(unsigned i=0;i<count;++i){
        unsigned ulp=bf16_ulp(got[i],expected[i]);
        float delta=bf16_float(got[i])-bf16_float(expected[i]);
        float abs=delta<0.0f?-delta:delta;
        unsigned micro=(unsigned)(abs*1000000.0f+0.5f);
        if(ulp>max_ulp) max_ulp=ulp;
        if(micro>max_abs_micro) max_abs_micro=micro;
        sum_sq+=(double)delta*(double)delta;
        if(ulp>16u && abs>0.002f){
            if(mismatches<4u)
                xil_printf("%s index=%u got=%04x expected=%04x ulp=%u abs_micro=%u\r\n",
                           name,i,got[i],expected[i],ulp,micro);
            ++mismatches;
        }
    }
    /* Fixed point mean squared error keeps xil_printf independent of floating printf. */
    unsigned mse_nano=(unsigned)(sum_sq*1000000000.0/(double)count+0.5);
    xil_printf("%s compare=%u mismatches=%u max_ulp=%u max_abs_micro=%u mse_nano=%u\r\n",
               name,count,mismatches,max_ulp,max_abs_micro,mse_nano);
    /* Bounded numerical tolerance accepted for BF16 layer-0 comparison. */
    return mse_nano>1000000u || max_abs_micro>200000u ? -1 : 0;
}
static int run_case(const char *name,const isa_record_spec *program,
                    unsigned count,unsigned rows,unsigned total,
                    const uint16_t *expected_layer,const uint16_t *expected_key,
                    const uint16_t *expected_value)
{
    unsigned record_index=0,chunk=0;
    uint32_t status;
    for(unsigned pc=0;pc<count;++pc){
        __uint128_t command=0;
        uint32_t words[4];
        for(unsigned i=0;i<4;++i) command|=(__uint128_t)program[pc].word[i]<<(32u*i);
        if(program[pc].source!=UINT32_MAX){
            const uint32_t (*base)[4]=source_base(program[pc].source);
            if(!base) return -1;
            uintptr_t address=(uintptr_t)&base[program[pc].offset_words];
            if(address>UINT32_MAX || (address&15u)){
                xil_printf("%s bad DDR address pc=%u addr=%08x\r\n",name,pc,(unsigned)address);
                return -1;
            }
            command|=(__uint128_t)(uint32_t)address<<25;
        }
        for(unsigned i=0;i<4;++i) words[i]=(uint32_t)(command>>(32u*i));
        if(host_op(1u,0u,record_index++,words,0)) return -1;
        if((command>>124)==0u){
            if(host_op(2u,0u,0u,zero,0)||wait_done(name,chunk)) return -1;
            xil_printf("%s chunk=%u DONE records=%u\r\n",name,chunk,record_index);
            ++chunk;
            record_index=0;
        }
    }
    if(record_index) return -1;
    /* END after FENCE and re-LOAD proves the store status and read path drained. */
    Xil_DCacheInvalidateRange((INTPTR)kv_key_words,total*384u);
    Xil_DCacheInvalidateRange((INTPTR)kv_value_words,total*384u);
    __asm__ volatile("dsb sy" ::: "memory");
    if(compare_values("DDR key",(const uint16_t *)kv_key_words,expected_key,total*192u)) return -1;
    if(compare_values("DDR value",(const uint16_t *)kv_value_words,expected_value,total*192u)) return -1;
    if(host_op(6u,0u,0u,zero,&status)) return -1;
    if((status&0xffffu)!=rows*72u){
        xil_printf("%s ADD count=%u expected=%u\r\n",name,(unsigned)(status&0xffffu),rows*72u);
        return -1;
    }
    for(unsigned i=0;i<rows*576u;++i){
        if(host_op(5u,0u,i,zero,&status)) return -1;
        layer_output_scratch[i]=(uint16_t)status;
    }
    return compare_values(name,layer_output_scratch,expected_layer,rows*576u);
}
int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 layer0 KV prefill32->decode1 probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    Xil_DCacheFlushRange((INTPTR)weight_words,sizeof(weight_words));
    Xil_DCacheFlushRange((INTPTR)kv_prefill32_embedding_words,sizeof(kv_prefill32_embedding_words));
    Xil_DCacheFlushRange((INTPTR)kv_prefill32_coeff_words,sizeof(kv_prefill32_coeff_words));
    Xil_DCacheFlushRange((INTPTR)kv_decode1_embedding_words,sizeof(kv_decode1_embedding_words));
    Xil_DCacheFlushRange((INTPTR)kv_decode1_coeff_words,sizeof(kv_decode1_coeff_words));
    Xil_DCacheFlushRange((INTPTR)kv_key_words,sizeof(kv_key_words));
    Xil_DCacheFlushRange((INTPTR)kv_value_words,sizeof(kv_value_words));
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq=(Xil_In32(GPIO_CTL+8u)>>31)&1u;
    int failed=run_case("prefill32",kv_prefill32_program,
        sizeof(kv_prefill32_program)/sizeof(kv_prefill32_program[0]),
        32u,32u,kv_prefill32_expected_layer0,
        kv_prefill32_expected_key,kv_prefill32_expected_value);
    if(!failed){
        failed=run_case("decode1",kv_decode1_program,
            sizeof(kv_decode1_program)/sizeof(kv_decode1_program[0]),
            1u,33u,kv_decode1_expected_layer0,
            kv_decode1_expected_key,kv_decode1_expected_value);
    }
    xil_printf(failed?"BOARD LAYER0 KV FAIL\r\n":"BOARD LAYER0 KV PASS\r\n");
    while(1){}
    return failed;
}
