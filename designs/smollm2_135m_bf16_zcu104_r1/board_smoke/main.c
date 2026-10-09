#include <stdint.h>
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"

/* Addresses assigned by create_gemm_board_smoke.tcl; confirm in the XSA. */
#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define GPIO_CH1 0u
#define GPIO_CH2 8u
#define TIMEOUT_POLLS 100000000u

static unsigned sequence;

static int transfer(unsigned op, unsigned bank, unsigned addr,
                    const uint32_t data[4], uint32_t *status_out)
{
    unsigned poll;
    uint32_t status = 0;
    Xil_Out32(GPIO_LO + GPIO_CH1, data[0]);
    Xil_Out32(GPIO_LO + GPIO_CH2, data[1]);
    Xil_Out32(GPIO_HI + GPIO_CH1, data[2]);
    Xil_Out32(GPIO_HI + GPIO_CH2, data[3]);
    __asm__ volatile("dsb sy" ::: "memory");
    sequence ^= 1u;
    Xil_Out32(GPIO_CTL + GPIO_CH1,
              (sequence << 31) | (op << 28) | (bank << 24) | addr);
    for (poll = 0; poll < TIMEOUT_POLLS; ++poll) {
        status = Xil_In32(GPIO_CTL + GPIO_CH2);
        if (((status >> 31) & 1u) == sequence &&
            ((status >> 30) & 1u) == 0u)
            break;
    }
    if (status_out != 0)
        *status_out = status;
    if (poll == TIMEOUT_POLLS || ((status >> 28) & 1u)) {
        xil_printf("TRANSFER FAIL op=%u bank=%u addr=%u status=%08x poll=%u\r\n",
                   op, bank, addr, (unsigned)status, poll);
        return -1;
    }
    return 0;
}

static int load_words(unsigned bank, const uint32_t (*words)[4], unsigned count)
{
    unsigned i;
    for (i = 0; i < count; ++i) {
        if (transfer(1u, bank, i, words[i], 0) != 0)
            return -1;
    }
    xil_printf("LOAD bank=%u words=%u OK\r\n", bank, count);
    return 0;
}

static int run_gemm(unsigned rows)
{
    /* The PS constructs only the agreed ISA record; it performs no GEMM. */
    const uint64_t payload = ((uint64_t)16u << 31) |
                             ((uint64_t)rows << 19) |
                             ((uint64_t)576u << 8) | 16u;
    const uint32_t command[4] = {
        (uint32_t)payload, (uint32_t)(payload >> 32),
        0u, 0x32340000u
    };
    uint32_t status = 0;
    if (transfer(2u, 0u, 0u, command, &status) != 0)
        return -1;
    if (((status >> 29) & 1u) == 0u) {
        xil_printf("GEMM DONE missing: %08x\r\n", (unsigned)status);
        return -1;
    }
    xil_printf("GEMM rows=%u columns=16 K=576 DONE\r\n", rows);
    return 0;
}

static int check_outputs(const char *name, const uint16_t *expected,
                         unsigned count)
{
    const uint32_t unused[4] = {0u, 0u, 0u, 0u};
    unsigned i, mismatches = 0;
    for (i = 0; i < count; ++i) {
        uint32_t status = 0;
        if (transfer(3u, 4u, i, unused, &status) != 0)
            return -1;
        if ((uint16_t)status != expected[i]) {
            if (mismatches < 8u)
                xil_printf("%s mismatch[%u] got=%04x expected=%04x\r\n",
                           name, i, (unsigned)((uint16_t)status),
                           (unsigned)expected[i]);
            ++mismatches;
        }
    }
    xil_printf("%s compare=%u mismatches=%u\r\n", name, count, mismatches);
    return mismatches == 0u ? 0 : -1;
}

int main(void)
{
    int failure = 0;
    xil_printf("SmolLM2-135M BF16 ZCU104 GEMM smoke\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    sequence = (Xil_In32(GPIO_CTL + GPIO_CH2) >> 31) & 1u;
    if (load_words(3u, q_proj_weight_words, 1152u) != 0)
        failure = 1;
    if (!failure && load_words(2u, prefill_activation_words, 2304u) != 0)
        failure = 1;
    if (!failure && run_gemm(32u) != 0)
        failure = 1;
    if (!failure && check_outputs("prefill32", prefill_expected, 512u) != 0)
        failure = 1;
    if (!failure && load_words(2u, decode_activation_words, 72u) != 0)
        failure = 1;
    if (!failure && run_gemm(1u) != 0)
        failure = 1;
    if (!failure && check_outputs("decode", decode_expected, 16u) != 0)
        failure = 1;
    xil_printf(failure ? "BOARD GEMM FAIL\r\n" : "BOARD GEMM PASS\r\n");
    while (1) { }
    return failure;
}
