#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"

#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u

static uint32_t prefill_ddr[2304][4] __attribute__((aligned(64)));
static uint32_t decode_ddr[72][4] __attribute__((aligned(64)));
static uint32_t gamma_ddr[72][4] __attribute__((aligned(64)));
static uint32_t qweight_ddr[41472][4] __attribute__((aligned(64)));
static uint32_t prefill_coeff_ddr[256][4] __attribute__((aligned(64)));
static uint32_t decode_coeff_ddr[8][4] __attribute__((aligned(64)));
static uint32_t prefill_k_ddr[768][4] __attribute__((aligned(64)));
static uint32_t decode_k_ddr[792][4] __attribute__((aligned(64)));
static uint32_t prefill_v_ddr[768][4] __attribute__((aligned(64)));
static uint32_t decode_v_ddr[792][4] __attribute__((aligned(64)));
static unsigned sequence;

static int host_op(unsigned op, unsigned bank, unsigned addr,
                   const uint32_t data[4], uint32_t *response)
{
    uint32_t status = 0;
    unsigned poll;
    Xil_Out32(GPIO_LO, data[0]); Xil_Out32(GPIO_LO + 8u, data[1]);
    Xil_Out32(GPIO_HI, data[2]); Xil_Out32(GPIO_HI + 8u, data[3]);
    __asm__ volatile("dsb sy" ::: "memory");
    sequence ^= 1u;
    Xil_Out32(GPIO_CTL, (sequence << 31) | (op << 28) |
                         (bank << 24) | addr);
    for (poll = 0; poll < POLL_LIMIT; ++poll) {
        status = Xil_In32(GPIO_CTL + 8u);
        if (((status >> 31) & 1u) == sequence &&
            ((status >> 30) & 1u) == 0u) break;
    }
    if (response) *response = status;
    if (poll == POLL_LIMIT || ((status >> 28) & 1u)) {
        xil_printf("HOST FAIL op=%u bank=%u addr=%u status=%08x\r\n",
                   op, bank, addr, (unsigned)status);
        return -1;
    }
    return 0;
}

static int record(unsigned index, __uint128_t command)
{
    uint32_t data[4];
    for (unsigned i = 0; i < 4; ++i)
        data[i] = (uint32_t)(command >> (32u * i));
    return host_op(1u, 0u, index, data, 0);
}

static __uint128_t dma_load(unsigned bank, unsigned bytes, uintptr_t address)
{
    return ((__uint128_t)1u << 124) | ((__uint128_t)bank << 120) |
           ((__uint128_t)bytes << 57) |
           ((__uint128_t)(uint32_t)address << 25);
}

static __uint128_t q_gemm(unsigned rows, unsigned n_start)
{
    return ((__uint128_t)3u << 124) | ((__uint128_t)2u << 120) |
           ((__uint128_t)3u << 116) | ((__uint128_t)4u << 112) |
           ((__uint128_t)n_start << 47) | ((__uint128_t)576u << 31) |
           ((__uint128_t)rows << 19) | ((__uint128_t)576u << 8) | 192u;
}

static __uint128_t attention(unsigned opcode, unsigned start,
                             unsigned rows, unsigned kv_len)
{
    __uint128_t banks = opcode == 6u ?
        (((__uint128_t)4u << 120) | ((__uint128_t)8u << 116) |
         ((__uint128_t)10u << 112)) :
        opcode == 8u ?
        (((__uint128_t)10u << 120) | ((__uint128_t)9u << 116) |
         ((__uint128_t)11u << 112)) : ((__uint128_t)10u << 120);
    return ((__uint128_t)opcode << 124) | banks |
           ((__uint128_t)start << 17) | ((__uint128_t)rows << 11) | kv_len;
}

static int publish_q_program(unsigned decode)
{
    unsigned rows = decode ? 1u : 32u;
    uintptr_t act = decode ? (uintptr_t)decode_ddr : (uintptr_t)prefill_ddr;
    uintptr_t coeff = decode ? (uintptr_t)decode_coeff_ddr :
                               (uintptr_t)prefill_coeff_ddr;
    unsigned index = 0;
    if (act > UINT32_MAX || coeff > UINT32_MAX ||
        (uintptr_t)gamma_ddr > UINT32_MAX ||
        (uintptr_t)qweight_ddr > UINT32_MAX) return -1;
    if (record(index++, dma_load(0u, rows*1152u, act)) != 0) return -1;
    if (record(index++, dma_load(3u, sizeof(gamma_ddr),
                                 (uintptr_t)gamma_ddr)) != 0) return -1;
    if (record(index++, ((__uint128_t)0x4032u << 112) | rows) != 0) return -1;
    for (unsigned tile = 0; tile < 3; ++tile) {
        if (record(index++, dma_load(3u, 221184u,
                (uintptr_t)&qweight_ddr[tile*13824u])) != 0) return -1;
        if (record(index++, q_gemm(rows, tile*192u)) != 0) return -1;
    }
    if (record(index++, dma_load(7u, rows*128u, coeff)) != 0) return -1;
    if (record(index++, ((__uint128_t)0x5470u << 112) | rows) != 0) return -1;
    return record(index, 0u);
}

static int publish_attention_program(unsigned decode)
{
    unsigned rows = decode ? 1u : 32u;
    unsigned start = decode ? 32u : 0u;
    unsigned kv_len = start + rows;
    uintptr_t key = decode ? (uintptr_t)decode_k_ddr :
                             (uintptr_t)prefill_k_ddr;
    uintptr_t value = decode ? (uintptr_t)decode_v_ddr :
                               (uintptr_t)prefill_v_ddr;
    if (key > UINT32_MAX || value > UINT32_MAX) return -1;
    if (record(0u, dma_load(8u, kv_len*384u, key)) != 0) return -1;
    if (record(1u, dma_load(9u, kv_len*384u, value)) != 0) return -1;
    if (record(2u, attention(6u, start, rows, kv_len)) != 0) return -1;
    if (record(3u, attention(7u, start, rows, kv_len)) != 0) return -1;
    if (record(4u, attention(8u, start, rows, kv_len)) != 0) return -1;
    return record(5u, 0u);
}

static int wait_done(const char *name)
{
    for (unsigned poll = 0; poll < POLL_LIMIT; ++poll) {
        uint32_t status = Xil_In32(GPIO_CTL + 8u);
        if ((status >> 28) & 1u) {
            xil_printf("%s ERROR status=%08x\r\n", name, (unsigned)status);
            return -1;
        }
        if ((status >> 27) & 1u) return 0;
    }
    xil_printf("%s TIMEOUT\r\n", name);
    return -1;
}

static unsigned bf16_ulp(uint16_t actual, uint16_t expected)
{
    unsigned a = actual & 0x8000u ? 0xffffu - actual : actual + 0x8000u;
    unsigned b = expected & 0x8000u ? 0xffffu - expected : expected + 0x8000u;
    return a > b ? a-b : b-a;
}

static int compare_output(const char *label, unsigned bank, unsigned rows,
                          unsigned writes, const uint16_t *expected,
                          unsigned tolerance)
{
    const uint32_t zero[4] = {0u, 0u, 0u, 0u};
    uint32_t status;
    unsigned mismatches = 0;
    if (host_op(6u, bank, 0u, zero, &status) != 0) return -1;
    if ((uint16_t)status != writes) {
        xil_printf("%s writes=%u expected=%u\r\n", label,
                   (unsigned)(uint16_t)status, writes);
        return -1;
    }
    for (unsigned i = 0; i < rows*16u; ++i) {
        if (host_op(5u, bank, i, zero, &status) != 0) return -1;
        if (bf16_ulp((uint16_t)status, expected[i]) > tolerance) {
            if (mismatches < 8)
                xil_printf("%s mismatch[%u] got=%04x expected=%04x\r\n",
                           label, i, (unsigned)(uint16_t)status,
                           (unsigned)expected[i]);
            ++mismatches;
        }
    }
    xil_printf("%s compare=%u mismatches=%u\r\n", label, rows*16u, mismatches);
    return mismatches ? -1 : 0;
}

static int run_case(unsigned decode)
{
    const uint32_t zero[4] = {0u, 0u, 0u, 0u};
    unsigned rows = decode ? 1u : 32u;
    unsigned kv_len = decode ? 33u : 32u;
    unsigned score_words = rows*9u*((kv_len+7u)/8u);
    if (publish_q_program(decode) != 0 ||
        host_op(2u, 0u, 0u, zero, 0) != 0 ||
        wait_done("Q program") != 0) return -1;
    if (compare_output(decode ? "decode Q" : "prefill32 Q", 4u, rows,
                       rows*72u, decode ? decode1_q_first16 :
                                           prefill32_q_first16, 8u) != 0) return -1;
    if (publish_attention_program(decode) != 0 ||
        host_op(2u, 0u, 0u, zero, 0) != 0 ||
        wait_done("attention program") != 0) return -1;
    if (compare_output(decode ? "decode score" : "prefill32 score", 13u,
                       rows, score_words,
                       decode ? decode1_score_first16 :
                                prefill32_score_first16, 16u) != 0) return -1;
    if (compare_output(decode ? "decode softmax" : "prefill32 softmax", 10u,
                       rows, score_words,
                       decode ? decode1_prob_first16 :
                                prefill32_prob_first16, 16u) != 0) return -1;
    return compare_output(decode ? "decode context" : "prefill32 context", 11u,
                          rows, rows*72u,
                          decode ? decode1_context_first16 :
                                   prefill32_context_first16, 16u);
}

int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 ATTN_SCORE+SOFTMAX+ATTN_VALUE probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
#define COPY(dst, src, count) \
    for (unsigned i = 0; i < (count); ++i) \
        for (unsigned j = 0; j < 4; ++j) (dst)[i][j] = (src)[i][j]
    COPY(prefill_ddr, prefill_input_words, 2304u);
    COPY(decode_ddr, decode_input_words, 72u);
    COPY(gamma_ddr, gamma_words, 72u);
    COPY(qweight_ddr, q_weight_words, 41472u);
    COPY(prefill_coeff_ddr, prefill_coeff_words, 256u);
    COPY(decode_coeff_ddr, decode_coeff_words, 8u);
    COPY(prefill_k_ddr, prefill_k_words, 768u);
    COPY(decode_k_ddr, decode_k_words, 792u);
    COPY(prefill_v_ddr, prefill_v_words, 768u);
    COPY(decode_v_ddr, decode_v_words, 792u);
#undef COPY
    Xil_DCacheFlushRange((INTPTR)prefill_ddr, sizeof(prefill_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_ddr, sizeof(decode_ddr));
    Xil_DCacheFlushRange((INTPTR)gamma_ddr, sizeof(gamma_ddr));
    Xil_DCacheFlushRange((INTPTR)qweight_ddr, sizeof(qweight_ddr));
    Xil_DCacheFlushRange((INTPTR)prefill_coeff_ddr, sizeof(prefill_coeff_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_coeff_ddr, sizeof(decode_coeff_ddr));
    Xil_DCacheFlushRange((INTPTR)prefill_k_ddr, sizeof(prefill_k_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_k_ddr, sizeof(decode_k_ddr));
    Xil_DCacheFlushRange((INTPTR)prefill_v_ddr, sizeof(prefill_v_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_v_ddr, sizeof(decode_v_ddr));
    __asm__ volatile("dsb sy" ::: "memory");
    sequence = (Xil_In32(GPIO_CTL + 8u) >> 31) & 1u;
    int failed = run_case(0u) != 0 || run_case(1u) != 0;
    xil_printf(failed ? "BOARD ATTN_SCORE SOFTMAX ATTN_VALUE FAIL\r\n" :
                        "BOARD ATTN_SCORE SOFTMAX ATTN_VALUE PASS\r\n");
    while (1) { }
    return failed;
}
