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
static uint32_t weight_ddr[1152][4] __attribute__((aligned(64)));
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

static __uint128_t gemm(unsigned rows)
{
    return ((__uint128_t)0x3234u << 112) |
           ((__uint128_t)16u << 31) |
           ((__uint128_t)rows << 19) |
           ((__uint128_t)576u << 8) | 16u;
}

static __uint128_t rmsnorm(unsigned rows)
{
    return ((__uint128_t)0x4032u << 112) | (__uint128_t)rows;
}

static int publish_program(unsigned decode)
{
    uintptr_t act = decode ? (uintptr_t)decode_ddr : (uintptr_t)prefill_ddr;
    unsigned bytes = decode ? 72u * 16u : sizeof(prefill_ddr);
    unsigned index = 0;
    if (act > UINT32_MAX || (uintptr_t)weight_ddr > UINT32_MAX ||
        (uintptr_t)gamma_ddr > UINT32_MAX) return -1;
    if (record(index++, dma_load(0u, bytes, act)) != 0) return -1;
    if (record(index++, dma_load(3u, sizeof(gamma_ddr),
                                 (uintptr_t)gamma_ddr)) != 0) return -1;
    if (record(index++, rmsnorm(decode ? 1u : 32u)) != 0) return -1;
    if (record(index++, dma_load(3u, sizeof(weight_ddr),
                                 (uintptr_t)weight_ddr)) != 0) return -1;
    if (record(index++, gemm(decode ? 1u : 32u)) != 0) return -1;
    return record(index, 0u);
}

static int wait_status(unsigned bit, const char *name)
{
    for (unsigned poll = 0; poll < POLL_LIMIT; ++poll) {
        uint32_t status = Xil_In32(GPIO_CTL + 8u);
        if ((status >> 28) & 1u) {
            xil_printf("%s ERROR status=%08x\r\n", name, (unsigned)status);
            return -1;
        }
        if ((status >> bit) & 1u) return 0;
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

static int compare_output(const char *label, unsigned bank,
                          unsigned rows, unsigned decode)
{
    const uint32_t empty[4] = {0u, 0u, 0u, 0u};
    uint32_t status;
    unsigned mismatches = 0;
    unsigned count = rows * 16u;
    unsigned words = bank == 2u ? rows * 72u : count;
    if (host_op(6u, bank, 0u, empty, &status) != 0) return -1;
    if ((uint16_t)status != words) {
        xil_printf("%s write count=%u expected=%u\r\n", label,
                   (unsigned)(uint16_t)status, words);
        return -1;
    }
    for (unsigned i = 0; i < count; ++i) {
        unsigned address = i;
        uint16_t expected = decode ? decode_expected_first16[i] :
                                     expected_first16[i];
        if (host_op(5u, bank, address, empty, &status) != 0) return -1;
        if (bf16_ulp((uint16_t)status, expected) > 2u) {
            if (mismatches < 8u)
                xil_printf("%s mismatch[%u] got=%04x expected=%04x\r\n",
                           label, i, (unsigned)(uint16_t)status,
                           (unsigned)expected);
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
        wait_status(27u, "RMS+GEMM END") != 0) return -1;
    if (compare_output(decode ? "decode RMS" : "prefill32 RMS", 2u,
                       rows, decode) != 0)
        return -1;
    return compare_output(decode ? "decode GEMM" : "prefill32 GEMM", 4u,
                          rows, decode);
}

int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 DMA_LOAD+RMSNORM+GEMM probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    for (unsigned i = 0; i < 2304u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            prefill_ddr[i][j] = prefill_input_words[i][j];
    for (unsigned i = 0; i < 72u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            decode_ddr[i][j] = decode_input_words[i][j];
    for (unsigned i = 0; i < 72u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            gamma_ddr[i][j] = gamma_words[i][j];
    for (unsigned i = 0; i < 1152u; ++i)
        for (unsigned j = 0; j < 4u; ++j)
            weight_ddr[i][j] = onehot_weight_words[i][j];
    Xil_DCacheFlushRange((INTPTR)prefill_ddr, sizeof(prefill_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_ddr, sizeof(decode_ddr));
    Xil_DCacheFlushRange((INTPTR)gamma_ddr, sizeof(gamma_ddr));
    Xil_DCacheFlushRange((INTPTR)weight_ddr, sizeof(weight_ddr));
    __asm__ volatile("dsb sy" ::: "memory");
    sequence = (Xil_In32(GPIO_CTL + 8u) >> 31) & 1u;
    int failed = run_chunk(0u) != 0 || run_chunk(1u) != 0;
    xil_printf(failed ? "BOARD DMA_LOAD RMSNORM GEMM FAIL\r\n" :
                        "BOARD DMA_LOAD RMSNORM GEMM PASS\r\n");
    while (1) { }
    return failed;
}
