#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "address_map.h"
#include "golden.h"
#include "program.h"
#ifdef LOAD_MODEL_FROM_SD
#include "sd_model_loader.h"
#endif
#ifdef PROBE_LM_HEAD_INPUT
#include "lm_head_input_golden.h"
#endif
#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u
static const uint32_t zero[4]={0,0,0,0};
static unsigned host_seq;
#ifdef PERF_ONLY
static uint64_t timer_count(void)
{
    uint64_t value;
    __asm__ volatile("mrs %0, cntvct_el0" : "=r"(value));
    return value;
}
static uint64_t timer_frequency(void)
{
    uint64_t value;
    __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(value));
    return value;
}
#endif
typedef struct {
    const char *name;
    unsigned rows,chunk,records;
    const uint16_t *expected_layer;
    uint32_t seen_probe_counters;
#ifdef PROFILE_PL
    uint64_t profile[24];
    uint64_t upload_ticks, start_ticks, wait_ticks, read_ticks;
#endif
} run_context;
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
static int flush_chunk(run_context *ctx)
{
    if(!ctx->records) return 0;
#ifdef PROFILE_PL
    uint64_t began=timer_count();
    if(host_op(1u,0u,ctx->records,zero,0)) return -1;
    ctx->upload_ticks+=timer_count()-began;
    began=timer_count();
    if(host_op(2u,0u,0u,zero,0)) return -1;
    ctx->start_ticks+=timer_count()-began;
    began=timer_count();
    if(wait_done(ctx->name,ctx->chunk)) return -1;
    ctx->wait_ticks+=timer_count()-began;
    began=timer_count();
    for(unsigned metric=0;metric<24u;++metric){
        uint64_t value=0;
        for(unsigned lane=0;lane<4u;++lane){
            uint32_t status;
            if(host_op(7u,0u,metric*4u+lane,zero,&status)) return -1;
            value|=(uint64_t)(status&0xffffu)<<(lane*16u);
        }
        ctx->profile[metric]+=value;
    }
    ctx->read_ticks+=timer_count()-began;
#else
    if(host_op(1u,0u,ctx->records,zero,0)||host_op(2u,0u,0u,zero,0)||
       wait_done(ctx->name,ctx->chunk)) return -1;
#endif
#ifndef PERF_ONLY
    if((ctx->chunk%16u)==0u)
        xil_printf("%s chunk=%u DONE records=%u\r\n",ctx->name,ctx->chunk,ctx->records+1u);
#endif
    ctx->chunk++;
    ctx->records=0;
    ctx->seen_probe_counters=0;
    return 0;
}
static int issue(void *opaque,const uint32_t words[4])
{
    run_context *ctx=(run_context *)opaque;
    uint32_t bit=smollm2_probe_counter_bit(words);
    if((ctx->seen_probe_counters&bit) && flush_chunk(ctx)) return -1;
    if(ctx->records>=15u) return -1;
#ifdef PROFILE_PL
    uint64_t began=timer_count();
#endif
    if(host_op(1u,0u,ctx->records,words,0)) return -1;
#ifdef PROFILE_PL
    ctx->upload_ticks+=timer_count()-began;
#endif
    ctx->records++;
    ctx->seen_probe_counters|=bit;
    return ctx->records==15u?flush_chunk(ctx):0;
}
#ifndef PERF_ONLY
static float bf16_float(uint16_t bits)
{
    union {uint32_t u;float f;} v;
    v.u=(uint32_t)bits<<16;
    return v.f;
}
static unsigned bf16_ulp(uint16_t a,uint16_t b)
{
    unsigned x=a&0x8000u?0xffffu-a:a+0x8000u;
    unsigned y=b&0x8000u?0xffffu-b:b+0x8000u;
    return x>y?x-y:y-x;
}
typedef struct {
    unsigned count,legacy_mismatches,max_ulp,max_abs_micro;
    double sum_sq,sum_abs;
    unsigned actual_top1,expected_top1;
    float actual_max,expected_max;
} comparison;
static void compare_one(comparison *c,unsigned index,uint16_t actual,uint16_t expected)
{
    float a=bf16_float(actual),b=bf16_float(expected);
    float delta=a-b,abs=delta<0.0f?-delta:delta;
    unsigned ulp=bf16_ulp(actual,expected);
    unsigned micro=(unsigned)(abs*1000000.0f+0.5f);
    if(index==0u||a>c->actual_max){c->actual_max=a;c->actual_top1=index;}
    if(index==0u||b>c->expected_max){c->expected_max=b;c->expected_top1=index;}
    if(ulp>c->max_ulp)c->max_ulp=ulp;
    if(micro>c->max_abs_micro)c->max_abs_micro=micro;
    if(ulp>16u&&abs>0.002f)c->legacy_mismatches++;
    c->sum_sq+=(double)delta*(double)delta;
    c->sum_abs+=(double)abs;
    c->count++;
}
static void report_comparison(const char *scope,unsigned index,const comparison *c)
{
    unsigned mse_nano=(unsigned)(c->sum_sq*1000000000.0/(double)c->count+0.5);
    unsigned mean_abs_micro=(unsigned)(c->sum_abs*1000000.0/(double)c->count+0.5);
    xil_printf("%s %u compare=%u mismatches=%u max_ulp=%u max_abs_micro=%u mean_abs_micro=%u mse_nano=%u\r\n",
       scope,index,c->count,c->legacy_mismatches,c->max_ulp,c->max_abs_micro,
       mean_abs_micro,mse_nano);
}
#endif
static int layer_done(void *opaque,unsigned layer)
{
    run_context *ctx=(run_context *)opaque;
    uint32_t status;
#ifndef PERF_ONLY
    comparison c={0};
#endif
    if(flush_chunk(ctx)) return -1;
    if(host_op(6u,0u,0u,zero,&status)) return -1;
    if((status&0xffffu)!=ctx->rows*72u){
        xil_printf("%s layer=%u ADD count=%u expected=%u\r\n",ctx->name,layer,
                   (unsigned)(status&0xffffu),ctx->rows*72u);
        return -1;
    }
#ifdef PERF_ONLY
    (void)layer;
#else
    for(unsigned row=0;row<ctx->rows;++row)
    for(unsigned col=0;col<16u;++col){
        unsigned index=row*16u+col;
        if(host_op(5u,0u,row*576u+col,zero,&status)) return -1;
        compare_one(&c,index,(uint16_t)status,
                    ctx->expected_layer[layer*ctx->rows*16u+index]);
    }
    report_comparison(ctx->name,layer,&c);
#endif
    return 0;
}
#ifndef PERF_ONLY
static int compare_logits(const char *name,const uint16_t *expected)
{
    comparison c={0};
    const volatile uint16_t *actual=(const volatile uint16_t *)(uintptr_t)MODEL_LOGITS_BASE;
    Xil_DCacheInvalidateRange((INTPTR)MODEL_LOGITS_BASE,49152u*2u);
    __asm__ volatile("dsb sy" ::: "memory");
    for(unsigned i=0;i<49152u;++i) compare_one(&c,i,actual[i],expected[i]);
    report_comparison(name,30u,&c);
    xil_printf("%s logits top1 board=%u reference=%u\r\n",name,
               c.actual_top1,c.expected_top1);
    return 0;
}
#endif
#ifdef PROBE_LM_HEAD_INPUT
static int compare_lm_head_input(const char *name,unsigned rows)
{
    comparison c={0};
    const uint16_t *expected = rows==32u
        ? expected_prefill_lm_input_first16
        : expected_decode_lm_input_first16;
    uint32_t status;
    for(unsigned col=0;col<16u;++col){
        if(host_op(5u,2u,(rows-1u)*16u+col,zero,&status)) return -1;
        uint16_t actual=(uint16_t)status;
        compare_one(&c,col,actual,expected[col]);
        xil_printf("%s LM_INPUT col=%u board=%04x reference=%04x\r\n",
                   name,col,(unsigned)actual,(unsigned)expected[col]);
    }
    report_comparison("LM_INPUT",rows,&c);
    return 0;
}
#endif
static int run_block(const char *name,const uint16_t *tokens,unsigned rows,
                     unsigned start,const uint16_t *expected_layer,
                     const uint16_t *expected_logits)
{
    run_context ctx={.name=name,.rows=rows,.expected_layer=expected_layer};
#ifdef PERF_ONLY
    xil_printf("PERF_BEGIN %s %u %u\r\n",name,start,start+rows);
    uint64_t began=timer_count();
#endif
    if(smollm2_emit_block(tokens,rows,start,issue,layer_done,&ctx)){
        xil_printf("%s ISA execution failed\r\n",name);
        return -1;
    }
    if(flush_chunk(&ctx)) return -1;
#ifdef PERF_ONLY
    uint64_t elapsed=timer_count()-began;
    uint64_t frequency=timer_frequency();
    if(!frequency || elapsed>UINT64_MAX/1000000u){
        xil_printf("ERROR PERF_TIMER\r\n");
        return -1;
    }
    uint64_t elapsed_us=elapsed*1000000u/frequency;
    if(!elapsed_us || elapsed_us>UINT32_MAX){
        xil_printf("ERROR PERF_TIMER_RANGE\r\n");
        return -1;
    }
    xil_printf("PERF_BLOCK %s %u %u %u %u\r\n",name,start,start+rows,
               ctx.chunk,(unsigned)elapsed_us);
#ifdef PROFILE_PL
    xil_printf("PROFILE_PS %s upload_us=%u start_ack_us=%u done_poll_us=%u readback_us=%u\r\n",
        name,(unsigned)(ctx.upload_ticks*1000000u/frequency),
        (unsigned)(ctx.start_ticks*1000000u/frequency),
        (unsigned)(ctx.wait_ticks*1000000u/frequency),
        (unsigned)(ctx.read_ticks*1000000u/frequency));
    for(unsigned i=0;i<24u;++i)
        xil_printf("PROFILE_PL %s %u %08x %08x\r\n",name,i,
            (unsigned)(ctx.profile[i]>>32),(unsigned)ctx.profile[i]);
#endif
    (void)expected_logits;
#else
    xil_printf("%s ISA DONE chunks=%u\r\n",name,ctx.chunk);
#ifdef PROBE_LM_HEAD_INPUT
    if(compare_lm_head_input(name,rows)) return -1;
#endif
    return compare_logits(name,expected_logits);
#endif
    return 0;
}
int main(void)
{
    static const uint16_t prefill_tokens[32]={11,28,45,62,79,96,113,130,
        147,164,181,198,215,232,249,266,283,300,317,334,351,368,385,
        402,419,436,453,470,487,504,521,538};
    static const uint16_t decode_tokens[1]={555};
#ifdef PERF_ONLY
#ifdef PROFILE_PL
    xil_printf("SmolLM2-135M BF16 ZCU104 128-bit PL profiler v1\r\n");
#else
    xil_printf("SmolLM2-135M BF16 ZCU104 fixed performance probe\r\n");
#endif
#else
    xil_printf("SmolLM2-135M BF16 ZCU104 full 30-layer ISA probe\r\n");
#endif
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    xil_printf("DDR static base=%08x bytes=%u logits=%08x\r\n",
       MODEL_DDR_BASE,MODEL_DDR_STATIC_BYTES,MODEL_LOGITS_BASE);
#ifdef LOAD_MODEL_FROM_SD
    if (load_model_from_sd()) {
        xil_printf("BOARD FULL MODEL ISA ERROR\r\n");
        while(1){}
    }
#endif
    host_seq=(Xil_In32(GPIO_CTL+8u)>>31)&1u;
    int failed=run_block("prefill32",prefill_tokens,32u,0u,
        expected_prefill_layer_first16,expected_prefill_logits);
    if(!failed) failed=run_block("decode1",decode_tokens,1u,32u,
        expected_decode_layer_first16,expected_decode_logits);
#ifdef PERF_ONLY
#ifdef PROFILE_PL
    xil_printf(failed?"BOARD PL PROFILE ERROR\r\n":"BOARD PL PROFILE COMPLETE\r\n");
#else
    xil_printf(failed?"BOARD FIXED PERFORMANCE ISA ERROR\r\n":
                      "BOARD FIXED PERFORMANCE ISA EXECUTION COMPLETE\r\n");
#endif
#else
    xil_printf(failed?"BOARD FULL MODEL ISA ERROR\r\n":
                      "BOARD FULL MODEL ISA EXECUTION COMPLETE; REVIEW LOGITS\r\n");
#endif
    while(1){}
    return failed;
}
