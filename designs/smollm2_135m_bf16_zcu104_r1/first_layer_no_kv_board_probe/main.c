#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"
#ifdef FIRST_LAYER_DIAGNOSTIC
#include "diagnostic_vectors.h"
#endif
#ifdef FIRST_LAYER_FULL_OUTPUT
#include "../first_layer_full_output_board_probe/full_output_vectors.h"
#endif
#ifdef FIRST_LAYER_STAGE_FULL
#include "../first_layer_stage_board_probe/stage_vectors.h"
#endif
#ifdef FIRST_LAYER_FFN_FULL
#include "../first_layer_ffn_board_probe/ffn_vectors.h"
#endif

#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u

static unsigned host_seq;
static const uint32_t zero[4] = {0, 0, 0, 0};
#ifdef FIRST_LAYER_STAGE_FULL
static unsigned stage_numeric_failures;
#endif
#ifdef FIRST_LAYER_FFN_FULL
static unsigned ffn_numeric_failures;
#endif

static int host_op(unsigned op, unsigned bank, unsigned addr,
                   const uint32_t data[4], uint32_t *response)
{
    uint32_t status = 0;
    unsigned poll;
    Xil_Out32(GPIO_LO, data[0]); Xil_Out32(GPIO_LO+8u, data[1]);
    Xil_Out32(GPIO_HI, data[2]); Xil_Out32(GPIO_HI+8u, data[3]);
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq ^= 1u;
    Xil_Out32(GPIO_CTL, (host_seq<<31)|(op<<28)|(bank<<24)|addr);
    for (poll=0; poll<POLL_LIMIT; ++poll) {
        status = Xil_In32(GPIO_CTL+8u);
        if (((status>>31)&1u)==host_seq && ((status>>30)&1u)==0u) break;
    }
    if (response) *response=status;
    if (poll==POLL_LIMIT || ((status>>28)&1u)) {
        xil_printf("HOST FAIL op=%u bank=%u addr=%u status=%08x\r\n",
                   op, bank, addr, (unsigned)status);
        return -1;
    }
    return 0;
}

static int wait_done(const char *name, unsigned chunk)
{
    for (unsigned poll=0; poll<POLL_LIMIT; ++poll) {
        uint32_t status=Xil_In32(GPIO_CTL+8u);
        if ((status>>28)&1u) {
            xil_printf("%s chunk=%u ERROR status=%08x\r\n",
                       name, chunk, (unsigned)status);
            return -1;
        }
        if ((status>>27)&1u) return 0;
    }
    xil_printf("%s chunk=%u TIMEOUT\r\n", name, chunk);
    return -1;
}

static unsigned bf16_ulp(uint16_t actual, uint16_t expected)
{
    unsigned a = actual & 0x8000u ? 0xffffu-actual : actual+0x8000u;
    unsigned b = expected & 0x8000u ? 0xffffu-expected : expected+0x8000u;
    return a>b ? a-b : b-a;
}

static float bf16_float(uint16_t bits)
{
    union { uint32_t u; float f; } value;
    value.u=(uint32_t)bits<<16;
    return value.f;
}

static const uint32_t (*source_base(unsigned source))[4]
{
    switch (source) {
    case 0: return prefill32_embedding_words;
    case 1: return prefill32_coeff_words;
    case 2: return single_token_cold_embedding_words;
    case 3: return single_token_cold_coeff_words;
    case 4: return weight_words;
    default: return 0;
    }
}

#ifdef FIRST_LAYER_DIAGNOSTIC
static int compare_tap(const char *stage, unsigned bank, unsigned rows,
                       unsigned words, const uint16_t *expected, unsigned columns)
{
    unsigned mismatches=0, max_ulp=0, max_abs_micro=0, worst_row=0, worst_col=0;
    uint32_t status;
    if (host_op(6u,bank,0u,zero,&status)) return -1;
    if ((status&0xffffu)!=words) {
        xil_printf("DIAG %s B%u count=%u expected=%u\r\n",stage,bank,
                   (unsigned)(status&0xffffu),words);
        return -1;
    }
    for (unsigned row=0; row<rows; ++row)
    for (unsigned col=0; col<columns; ++col) {
        unsigned index=row*16u+col;
        unsigned distance, absolute_micro;
        float absolute_error;
        uint16_t actual;
        unsigned read_index=index;
#ifdef FIRST_LAYER_FULL_OUTPUT
        if (bank==0u) read_index=row*576u+col;
#endif
#ifdef FIRST_LAYER_STAGE_FULL
        if (bank==5u && stage[0]=='a') read_index=row*576u+col;
#endif
#ifdef FIRST_LAYER_FFN_FULL
        if (bank==2u && rows==32u &&
            stage[0]=='p') read_index=row*576u+col;
        if (bank==2u && rows==1u &&
            stage[0]=='p') read_index=row*576u+col;
#endif


        if (host_op(5u,bank,read_index,zero,&status)) return -1;
        actual=(uint16_t)status;
#ifdef FIRST_LAYER_OUTPUT_DUMP
        if (bank==0u) {
            if (col==0u) xil_printf("FINAL_VALUES row=%u",row);
            xil_printf(" %04x",actual);
            if (col+1u==columns) xil_printf("\r\n");
        }
#endif
        distance=bf16_ulp(actual,expected[index]);
        absolute_error=bf16_float(actual)-bf16_float(expected[index]);
        if (absolute_error<0.0f) absolute_error=-absolute_error;
        absolute_micro=(unsigned)(absolute_error*1000000.0f+0.5f);
        if (absolute_micro>max_abs_micro) {
            max_abs_micro=absolute_micro; worst_row=row; worst_col=col;
        }
        if (distance>max_ulp) max_ulp=distance;
        if (distance>16u && absolute_error>0.002f) {
            if (mismatches<4u)
                xil_printf("DIAG %s row=%u col=%u got=%04x expected=%04x ulp=%u abs_micro=%u\r\n",
                           stage,row,col,actual,expected[index],distance,absolute_micro);
            ++mismatches;
        }
    }
    xil_printf("DIAG %s B%u compare=%u mismatches=%u max_ulp=%u max_abs_micro=%u worst=%u,%u\r\n",
               stage,bank,rows*columns,mismatches,max_ulp,max_abs_micro,worst_row,worst_col);
    return 0;
}

static int diagnostic_chunk(const char *name, unsigned chunk, unsigned rows)
{
    int prefill=(rows==32u);
    if ((prefill && chunk==2u) || (!prefill && chunk==0u)) {
        if (compare_tap("input_norm",2u,rows,rows*72u,
            prefill?prefill32_input_norm_first16:single_token_cold_input_norm_first16,16u)) return -1;
        if (!prefill) return compare_tap("q_rope",4u,rows,rows*72u,
            single_token_cold_q_rope_first16,16u);
        return 0;
    }
    if ((prefill && chunk==3u) || (!prefill && chunk==1u)) {
        if (prefill && compare_tap("q_rope",4u,rows,rows*72u,
            prefill32_q_rope_first16,16u)) return -1;
        if (compare_tap("k_rope",8u,rows,rows*24u,
            prefill?prefill32_k_rope_first16:single_token_cold_k_rope_first16,16u)) return -1;
        if (compare_tap("score",13u,rows,rows*9u*((rows+7u)/8u),
            prefill?prefill32_score_first16:single_token_cold_score_first16,
            prefill?16u:8u)) return -1;
        if (compare_tap("prob",10u,rows,rows*9u*((rows+7u)/8u),
            prefill?prefill32_prob_first16:single_token_cold_prob_first16,
            prefill?16u:8u)) return -1;
        if (compare_tap("context",11u,rows,rows*72u,
            prefill?prefill32_context_first16:single_token_cold_context_first16,16u)) return -1;
        if (compare_tap("attention_residual",5u,rows,rows*72u,
            prefill?prefill32_attention_residual_first16:single_token_cold_attention_residual_first16,16u)) return -1;
        return compare_tap("post_norm",2u,rows,rows*72u,
            prefill?prefill32_post_norm_first16:single_token_cold_post_norm_first16,16u);
    }
    if ((prefill && chunk==
#ifdef FIRST_LAYER_FFN_FULL
        8u
#else
        6u
#endif
        ) || (!prefill && chunk==
#ifdef FIRST_LAYER_FFN_FULL
        6u
#else
        4u
#endif
        )) {
#ifndef FIRST_LAYER_FFN_FULL
        if (compare_tap("silu",14u,rows,rows*192u,
            prefill?prefill32_silu_first16:single_token_cold_silu_first16,16u)) return -1;
#endif
        return compare_tap("final",0u,rows,rows*72u,
            prefill?prefill32_final_first16:single_token_cold_final_first16,16u);
    }
    (void)name;
    return 0;
}
#endif

#ifdef FIRST_LAYER_STAGE_FULL
static int compare_stage_full(const char *name, const char *stage,
                              unsigned bank, unsigned rows,
                              const uint16_t *expected)
{
    uint32_t status;
    unsigned mismatches=0, max_ulp=0;
    unsigned expected_writes=rows*576u/(bank==1u ? 1u : 8u);
    if (host_op(6u,bank,0u,zero,&status)) return -1;
    if ((status&0xffffu)!=expected_writes) {
        xil_printf("STAGE %s B%u writes=%u expected=%u\r\n",stage,bank,
                   (unsigned)(status&0xffffu),expected_writes);
        return -1;
    }
    for (unsigned row=0; row<rows; ++row) {
        xil_printf("STAGE_FULL %s %s row=%u",name,stage,row);
        for (unsigned col=0; col<576u; ++col) {
            unsigned index=row*576u+col;
            uint16_t actual;
            unsigned distance;
            float absolute_error;
            if (host_op(5u,bank,index,zero,&status)) return -1;
            actual=(uint16_t)status;
            xil_printf(" %04x",actual);
            distance=bf16_ulp(actual,expected[index]);
            if (distance>max_ulp) max_ulp=distance;
            absolute_error=bf16_float(actual)-bf16_float(expected[index]);
            if (absolute_error<0.0f) absolute_error=-absolute_error;
            if (distance>16u && absolute_error>0.002f) ++mismatches;
        }
        xil_printf("\r\n");
    }
    xil_printf("STAGE %s %s compare=%u mismatches=%u max_ulp=%u\r\n",
               name,stage,rows*576u,mismatches,max_ulp);
    stage_numeric_failures+=mismatches;
    return 0;
}
#endif

#ifdef FIRST_LAYER_FFN_FULL
static int compare_ffn_full(const char *name, const char *stage,
                            unsigned bank, unsigned rows, unsigned columns,
                            const uint16_t *expected)
{
    uint32_t status;
    unsigned mismatches=0, max_ulp=0;
    unsigned expected_writes=rows*columns/(bank==8u || bank==9u ? 1u : 8u);
    if (host_op(6u,bank,0u,zero,&status)) return -1;
    if ((status&0xffffu)!=expected_writes) {
        xil_printf("FFN %s %s B%u writes=%u expected=%u\r\n",name,stage,bank,
                   (unsigned)(status&0xffffu),expected_writes);
        return -1;
    }
    for (unsigned row=0; row<rows; ++row) {
        for (unsigned col=0; col<columns; ++col) {
            unsigned index=row*columns+col;
            uint16_t actual;
            unsigned distance;
            float absolute_error;
            if (host_op(5u,bank,index,zero,&status)) return -1;
            actual=(uint16_t)status;
            if (col%128u==0u)
                xil_printf("FFN_FULL %s %s row=%u offset=%u",name,stage,row,col);
            xil_printf(" %04x",actual);
            if (col%128u==127u || col+1u==columns) xil_printf("\r\n");
            distance=bf16_ulp(actual,expected[index]);
            if (distance>max_ulp) max_ulp=distance;
            absolute_error=bf16_float(actual)-bf16_float(expected[index]);
            if (absolute_error<0.0f) absolute_error=-absolute_error;
            if (distance>16u && absolute_error>0.002f) ++mismatches;
        }
    }
    xil_printf("FFN %s %s compare=%u mismatches=%u max_ulp=%u\r\n",
               name,stage,rows*columns,mismatches,max_ulp);
    ffn_numeric_failures+=mismatches;
    return 0;
}

static int finish_inserted_chunk(const char *name, unsigned *chunk,
                                 unsigned *record_index)
{
    if (host_op(1u,0u,(*record_index)++,zero,0) ||
        host_op(2u,0u,0u,zero,0) || wait_done(name,*chunk)) return -1;
    xil_printf("%s chunk=%u DONE records=%u inserted-END\r\n",
               name,*chunk,*record_index);
    ++*chunk;
    *record_index=0;
    return 0;
}

static int ffn_stage_capture(const char *name, unsigned rows,
                             unsigned pc, unsigned *chunk,
                             unsigned *record_index, int original_end)
{
    int prefill=rows==32u;
    if ((prefill && original_end && pc==47u) ||
        (!prefill && original_end && pc==15u))
        return host_op(7u,2u,0u,zero,0);
    if (!prefill && !original_end && pc==29u) {
        if (finish_inserted_chunk(name,chunk,record_index)) return -1;
#ifdef FIRST_LAYER_DIAGNOSTIC
        if (diagnostic_chunk(name,1u,rows)) return -1;
#endif
#ifdef FIRST_LAYER_STAGE_FULL
        if (compare_stage_full(name,"attention_residual",5u,rows,
                               single_token_cold_attention_residual_full)) return -1;
#endif
    } else if (prefill && !original_end && (pc==96u || pc==97u)) {
        if (finish_inserted_chunk(name,chunk,record_index)) return -1;
    } else if (!prefill && !original_end && pc==64u) {
        if (finish_inserted_chunk(name,chunk,record_index)) return -1;
    } else if (!original_end) return 0;

    if ((prefill && original_end && pc==63u) ||
        (!prefill && !original_end && pc==29u)) {
        if (compare_ffn_full(name,"post_norm",2u,rows,576u,
            prefill ? prefill32_post_norm_full : single_token_cold_post_norm_full)) return -1;
        return host_op(7u,8u,0u,zero,0);
    }
    if ((prefill && original_end && pc==79u) ||
        (!prefill && original_end && pc==47u)) {
        if (compare_ffn_full(name,"gate_projection",8u,rows,1536u,
            prefill ? prefill32_gate_projection_full : single_token_cold_gate_projection_full)) return -1;
        return host_op(7u,9u,0u,zero,0);
    }
    if ((prefill && !original_end && pc==96u) ||
        (!prefill && original_end && pc==63u)) {
        if (compare_ffn_full(name,"up_projection",9u,rows,1536u,
            prefill ? prefill32_up_projection_full : single_token_cold_up_projection_full)) return -1;
        return host_op(7u,10u,0u,zero,0);
    }
    if ((prefill && !original_end && pc==97u) ||
        (!prefill && !original_end && pc==64u)) {
#ifdef FIRST_LAYER_DIAGNOSTIC
        if (compare_tap("silu",14u,rows,rows*192u,
            prefill ? prefill32_silu_first16 : single_token_cold_silu_first16,
            16u)) return -1;
#endif
        if (compare_ffn_full(name,"silu_mul",10u,rows,1536u,
            prefill ? prefill32_silu_mul_full : single_token_cold_silu_mul_full)) return -1;
        return host_op(7u,15u,0u,zero,0);
    }
    return 0;
}
#endif

static int run_case(const char *name, const isa_record_spec *program,
                    unsigned count, unsigned rows, const uint16_t *expected)
{
    unsigned record_index=0, chunk=0, mismatches=0, max_ulp=0;
    uint32_t status;
#ifdef FIRST_LAYER_FFN_FULL
    if (host_op(7u,15u,0u,zero,0)) return -1;
#endif
    for (unsigned pc=0; pc<count; ++pc) {
        __uint128_t command=0;
        uint32_t words[4];
        for (unsigned i=0; i<4; ++i)
            command |= (__uint128_t)program[pc].word[i] << (32u*i);
        if (program[pc].source != UINT32_MAX) {
            const uint32_t (*base)[4]=source_base(program[pc].source);
            if (!base) return -1;
            uintptr_t address=(uintptr_t)&base[program[pc].offset_words];
            if (address>UINT32_MAX || (address & 15u)) {
                xil_printf("%s bad DDR address pc=%u\r\n",name,pc);
                return -1;
            }
            command |= (__uint128_t)(uint32_t)address << 25;
        }
        for (unsigned i=0; i<4; ++i) words[i]=(uint32_t)(command>>(32u*i));
        if (host_op(1u,0u,record_index++,words,0)) return -1;
        if ((command>>124)==0u) {
            if (host_op(2u,0u,0u,zero,0) || wait_done(name,chunk)) return -1;
            xil_printf("%s chunk=%u DONE records=%u\r\n",name,chunk,record_index);
#ifdef FIRST_LAYER_DIAGNOSTIC
            if (diagnostic_chunk(name,chunk,rows)) return -1;
#endif
#ifdef FIRST_LAYER_STAGE_FULL
            if ((rows==32u && chunk==3u) ||
#ifndef FIRST_LAYER_FFN_FULL
                (rows==1u && chunk==1u)
#else
                0
#endif
                ) {
                if (compare_stage_full(name,"attention_residual",5u,rows,
                    rows==32u ? prefill32_attention_residual_full :
                                single_token_cold_attention_residual_full)) return -1;
            }
            if ((rows==32u && chunk==
#ifdef FIRST_LAYER_FFN_FULL
                8u
#else
                6u
#endif
                ) || (rows==1u && chunk==
#ifdef FIRST_LAYER_FFN_FULL
                6u
#else
                4u
#endif
                )) {
                if (compare_stage_full(name,"down_projection",1u,rows,
                    rows==32u ? prefill32_down_projection_full :
                                single_token_cold_down_projection_full)) return -1;
            }
#endif
            ++chunk;
            record_index=0;
        }
#ifdef FIRST_LAYER_FFN_FULL
        if (ffn_stage_capture(name,rows,pc,&chunk,&record_index,
                              (command>>124)==0u)) return -1;
#endif
    }
    if (record_index) return -1;
    if (host_op(6u,0u,0u,zero,&status)) return -1;
    if ((status&0xffffu)!=rows*72u) {
        xil_printf("%s ADD write count=%u expected=%u\r\n",
                   name,(unsigned)(status&0xffffu),rows*72u);
        return -1;
    }
#ifdef FIRST_LAYER_FULL_OUTPUT
    const unsigned columns=576u;
#else
    const unsigned columns=16u;
#endif
    for (unsigned row=0; row<rows; ++row)
    for (unsigned col=0; col<columns; ++col) {
        unsigned i=row*columns+col;
        uint16_t actual;
        unsigned distance;
        if (host_op(5u,0u,i,zero,&status)) return -1;
        actual=(uint16_t)status;
#ifdef FIRST_LAYER_FULL_OUTPUT
        if (col==0u) xil_printf("FINAL_FULL %s row=%u",name,row);
        xil_printf(" %04x",actual);
        if (col+1u==columns) xil_printf("\r\n");
#endif
        distance=bf16_ulp(actual,expected[i]);
        if (distance>max_ulp) max_ulp=distance;
        float absolute_error=bf16_float(actual)-bf16_float(expected[i]);
        if (absolute_error<0.0f) absolute_error=-absolute_error;
        if (distance>16u && absolute_error>0.002f) {
#ifndef FIRST_LAYER_FULL_OUTPUT
            if (mismatches<8u)
                xil_printf("%s row=%u col=%u got=%04x expected=%04x ulp=%u\r\n",
                           name,row,col,actual,expected[i],distance);
#endif
            ++mismatches;
        }
    }
    xil_printf("%s final ADD compare=%u mismatches=%u max_ulp=%u\r\n",
               name,rows*columns,mismatches,max_ulp);
    return mismatches ? -1 : 0;
}

int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 first-layer ISA no-KV probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    Xil_DCacheFlushRange((INTPTR)weight_words,sizeof(weight_words));
    Xil_DCacheFlushRange((INTPTR)prefill32_embedding_words,sizeof(prefill32_embedding_words));
    Xil_DCacheFlushRange((INTPTR)prefill32_coeff_words,sizeof(prefill32_coeff_words));
    Xil_DCacheFlushRange((INTPTR)single_token_cold_embedding_words,sizeof(single_token_cold_embedding_words));
    Xil_DCacheFlushRange((INTPTR)single_token_cold_coeff_words,sizeof(single_token_cold_coeff_words));
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq=(Xil_In32(GPIO_CTL+8u)>>31)&1u;
#ifdef FIRST_LAYER_FULL_OUTPUT
    const uint16_t *prefill_expected=prefill32_expected_full;
    const uint16_t *single_expected=single_token_cold_expected_full;
#else
    const uint16_t *prefill_expected=prefill32_expected_first16;
    const uint16_t *single_expected=single_token_cold_expected_first16;
#endif
    int prefill_failed=run_case("prefill32",prefill32_program,
                        sizeof(prefill32_program)/sizeof(prefill32_program[0]),
                        32u,prefill_expected);
    int single_failed=run_case("single_token_cold",single_token_cold_program,
                        sizeof(single_token_cold_program)/sizeof(single_token_cold_program[0]),
                        1u,single_expected);
    int failed=prefill_failed || single_failed;
#ifdef FIRST_LAYER_STAGE_FULL
    if (stage_numeric_failures) failed=1;
#endif
#ifdef FIRST_LAYER_FFN_FULL
    if (ffn_numeric_failures) failed=1;
#endif
    xil_printf(failed ? "BOARD FIRST LAYER ISA FAIL\r\n" :
                        "BOARD FIRST LAYER ISA PASS\r\n");
    while (1) {}
    return failed;
}
