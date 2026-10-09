#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"
#include "softmax_vectors.h"

#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u

static uint32_t prefill_ddr[2304][4] __attribute__((aligned(64)));
static uint32_t decode_ddr[72][4] __attribute__((aligned(64)));
static uint32_t gamma_ddr[72][4] __attribute__((aligned(64)));
static uint32_t weight_ddr[13824][4] __attribute__((aligned(64)));
static uint32_t prefill_coeff_ddr[256][4] __attribute__((aligned(64)));
static uint32_t decode_coeff_ddr[8][4] __attribute__((aligned(64)));
static uint32_t key_probe_ddr[792][4] __attribute__((aligned(64)));
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

static __uint128_t gemm(unsigned output_bank, unsigned rows,
                        unsigned n_start, unsigned n_total)
{
    return ((__uint128_t)3u << 124) | ((__uint128_t)2u << 120) |
           ((__uint128_t)3u << 116) | ((__uint128_t)output_bank << 112) |
           ((__uint128_t)n_start << 47) | ((__uint128_t)n_total << 31) |
           ((__uint128_t)rows << 19) | ((__uint128_t)576u << 8) | 192u;
}

static __uint128_t rmsnorm(unsigned rows)
{
    return ((__uint128_t)0x4032u << 112) | (__uint128_t)rows;
}

static __uint128_t rope(unsigned bank, unsigned rows)
{
    return ((__uint128_t)5u << 124) | ((__uint128_t)bank << 120) |
           ((__uint128_t)7u << 116) | (__uint128_t)rows;
}

static __uint128_t attention_shape(unsigned opcode, unsigned start,
                                    unsigned rows, unsigned kv_len)
{
    __uint128_t banks = opcode == 6u ?
        (((__uint128_t)4u << 120) | ((__uint128_t)8u << 116) |
         ((__uint128_t)10u << 112)) : ((__uint128_t)10u << 120);
    return ((__uint128_t)opcode << 124) | banks |
           ((__uint128_t)start << 17) | ((__uint128_t)rows << 11) | kv_len;
}

static int publish_program(unsigned decode)
{
    uintptr_t act = decode ? (uintptr_t)decode_ddr : (uintptr_t)prefill_ddr;
    uintptr_t coeff = decode ? (uintptr_t)decode_coeff_ddr :
                               (uintptr_t)prefill_coeff_ddr;
    unsigned rows = decode ? 1u : 32u;
    unsigned input_bytes = rows * 1152u;
    unsigned coeff_bytes = rows * 128u;
    unsigned start = decode ? 32u : 0u;
    unsigned kv_len = start + rows;
    unsigned index = 0;
    if (act > UINT32_MAX || coeff > UINT32_MAX ||
        (uintptr_t)weight_ddr > UINT32_MAX ||
        (uintptr_t)gamma_ddr > UINT32_MAX ||
        (uintptr_t)key_probe_ddr > UINT32_MAX) return -1;
    if (record(index++, dma_load(0u, input_bytes, act)) != 0) return -1;
    if (record(index++, dma_load(3u, sizeof(gamma_ddr),
                                 (uintptr_t)gamma_ddr)) != 0) return -1;
    if (record(index++, rmsnorm(rows)) != 0) return -1;
    if (record(index++, dma_load(3u, sizeof(weight_ddr),
                                 (uintptr_t)weight_ddr)) != 0) return -1;
    for (unsigned n = 0; n < 576u; n += 192u)
        if (record(index++, gemm(4u, rows, n, 576u)) != 0) return -1;
    if (record(index++, gemm(5u, rows, 0u, 192u)) != 0) return -1;
    if (record(index++, dma_load(7u, coeff_bytes, coeff)) != 0) return -1;
    if (record(index++, rope(4u, rows)) != 0) return -1;
    if (record(index++, rope(5u, rows)) != 0) return -1;
    if (record(index++, dma_load(8u, kv_len * 384u,
                                 (uintptr_t)key_probe_ddr)) != 0) return -1;
    if (record(index++, attention_shape(6u, start, rows, kv_len)) != 0) return -1;
    if (record(index++, attention_shape(7u, start, rows, kv_len)) != 0) return -1;
    return record(index, 0u);
}

static int feed_score_probe(unsigned decode)
{
    uint32_t status;
    const uint32_t empty[4] = {0u, 0u, 0u, 0u};
    const uint32_t (*words)[4] = decode ? decode1_score_words :
                                         prefill32_score_words;
    unsigned count = decode ? 45u : 1152u;
    unsigned poll;
    for (poll = 0; poll < POLL_LIMIT; ++poll) {
        status = Xil_In32(GPIO_CTL + 8u);
        if ((status >> 28) & 1u) return -1;
        if ((status >> 29) & 1u) break;
    }
    if (poll == POLL_LIMIT) {
        xil_printf("SCORE PROBE TIMEOUT\r\n");
        return -1;
    }
    for (unsigned i = 0; i < count; ++i)
        if (host_op(3u, 10u, i, words[i], 0) != 0) return -1;
    return host_op(4u, 10u, 0u, empty, 0);
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
    return a > b ? a - b : b - a;
}

static int compare_output(const char *label, unsigned bank, unsigned rows,
                          const uint16_t *expected)
{
    const uint32_t empty[4] = {0u, 0u, 0u, 0u};
    uint32_t status;
    unsigned mismatches = 0;
    unsigned count = rows * 16u;
    unsigned words = rows * (bank == 4u ? 72u :
                            bank == 5u ? 24u :
                            9u * (((rows == 1u ? 33u : 32u) + 7u) / 8u));
    if (host_op(6u, bank, 0u, empty, &status) != 0) return -1;
    if ((uint16_t)status != words) {
        xil_printf("%s write count=%u expected=%u\r\n", label,
                   (unsigned)(uint16_t)status, words);
        return -1;
    }
    for (unsigned i = 0; i < count; ++i) {
        if (host_op(5u, bank, i, empty, &status) != 0) return -1;
        if (bf16_ulp((uint16_t)status, expected[i]) > 2u) {
            if (mismatches < 8u)
                xil_printf("%s mismatch[%u] got=%04x expected=%04x\r\n",
                           label, i, (unsigned)(uint16_t)status,
                           (unsigned)expected[i]);
            ++mismatches;
        }
    }
    xil_printf("%s compare=%u mismatches=%u\r\n", label, count, mismatches);
    return mismatches ? -1 : 0;
}

static int run_chunk(unsigned decode)
{
    const uint32_t empty[4] = {0u, 0u, 0u, 0u};
    unsigned rows = decode ? 1u : 32u;
    if (publish_program(decode) != 0 ||
        host_op(2u, 0u, 0u, empty, 0) != 0 ||
        feed_score_probe(decode) != 0 ||
        wait_done("RMS+GEMM+ROPE+SOFTMAX END") != 0) return -1;
    if (compare_output(decode ? "decode Q RoPE" : "prefill32 Q RoPE",
                       4u, rows, decode ? decode_q_first16 :
                                          prefill_q_first16) != 0) return -1;
    if (compare_output(decode ? "decode K RoPE" : "prefill32 K RoPE",
                       5u, rows, decode ? decode_k_first16 :
                                          prefill_k_first16) != 0) return -1;
    return compare_output(decode ? "decode Softmax" : "prefill32 Softmax",
                          10u, rows, decode ? decode1_softmax_first16 :
                                              prefill32_softmax_first16);
}

int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 DMA_LOAD+RMSNORM+GEMM+ROPE+SOFTMAX probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    for (unsigned i = 0; i < 2304u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            prefill_ddr[i][j] = prefill_input_words[i][j];
    for (unsigned i = 0; i < 72u; ++i)
        for (unsigned j = 0; j < 4u; ++j) {
            decode_ddr[i][j] = decode_input_words[i][j];
            gamma_ddr[i][j] = gamma_words[i][j];
        }
    for (unsigned i = 0; i < 13824u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            weight_ddr[i][j] = onehot192_weight_words[i][j];
    for (unsigned i = 0; i < 256u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            prefill_coeff_ddr[i][j] = prefill_coeff_words[i][j];
    for (unsigned i = 0; i < 8u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            decode_coeff_ddr[i][j] = decode_coeff_words[i][j];
    Xil_DCacheFlushRange((INTPTR)prefill_ddr, sizeof(prefill_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_ddr, sizeof(decode_ddr));
    Xil_DCacheFlushRange((INTPTR)gamma_ddr, sizeof(gamma_ddr));
    Xil_DCacheFlushRange((INTPTR)weight_ddr, sizeof(weight_ddr));
    Xil_DCacheFlushRange((INTPTR)prefill_coeff_ddr, sizeof(prefill_coeff_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_coeff_ddr, sizeof(decode_coeff_ddr));
    Xil_DCacheFlushRange((INTPTR)key_probe_ddr, sizeof(key_probe_ddr));
    __asm__ volatile("dsb sy" ::: "memory");
    sequence = (Xil_In32(GPIO_CTL + 8u) >> 31) & 1u;
    int failed = run_chunk(0u) != 0 || run_chunk(1u) != 0;
    xil_printf(failed ? "BOARD DMA_LOAD RMSNORM GEMM ROPE SOFTMAX FAIL\r\n" :
                        "BOARD DMA_LOAD RMSNORM GEMM ROPE SOFTMAX PASS\r\n");
    while (1) { }
    return failed;
}
