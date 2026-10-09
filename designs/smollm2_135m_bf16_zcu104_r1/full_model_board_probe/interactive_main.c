#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartps_hw.h"
#include "address_map.h"
#include "program.h"
#include "sd_model_loader.h"

#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u
#define LOGIT_BYTES (49152u * 2u)
static const uint32_t zero[4] = {0u, 0u, 0u, 0u};
static unsigned host_seq;
static unsigned next_position;

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

typedef struct {
    unsigned chunk, records, rows;
} run_context;

static int host_op(unsigned op, unsigned bank, unsigned addr,
                   const uint32_t data[4], uint32_t *response)
{
    uint32_t status = 0u;
    unsigned poll;
    Xil_Out32(GPIO_LO, data[0]); Xil_Out32(GPIO_LO + 8u, data[1]);
    Xil_Out32(GPIO_HI, data[2]); Xil_Out32(GPIO_HI + 8u, data[3]);
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq ^= 1u;
    Xil_Out32(GPIO_CTL, (host_seq << 31) | (op << 28) | (bank << 24) | addr);
    for (poll = 0u; poll < POLL_LIMIT; ++poll) {
        status = Xil_In32(GPIO_CTL + 8u);
        if (((status >> 31) & 1u) == host_seq && ((status >> 30) & 1u) == 0u)
            break;
    }
    if (response) *response = status;
    if (poll == POLL_LIMIT || ((status >> 28) & 1u)) {
        xil_printf("ERROR HOST op=%u bank=%u addr=%u status=%08x\r\n",
                   op, bank, addr, (unsigned)status);
        return -1;
    }
    return 0;
}

static int flush_chunk(run_context *context)
{
    if (!context->records) return 0;
    if (host_op(1u, 0u, context->records, zero, 0) ||
        host_op(2u, 0u, 0u, zero, 0)) return -1;
    for (unsigned poll = 0u; poll < POLL_LIMIT; ++poll) {
        uint32_t status = Xil_In32(GPIO_CTL + 8u);
        if ((status >> 28) & 1u) {
            xil_printf("ERROR DISPATCH chunk=%u status=%08x\r\n",
                       context->chunk, (unsigned)status);
            return -1;
        }
        if ((status >> 27) & 1u) {
            context->chunk++;
            context->records = 0u;
            return 0;
        }
    }
    xil_printf("ERROR TIMEOUT chunk=%u\r\n", context->chunk);
    return -1;
}

static int issue(void *opaque, const uint32_t words[4])
{
    run_context *context = (run_context *)opaque;
    if (context->records >= 15u) return -1;
    if (host_op(1u, 0u, context->records, words, 0)) return -1;
    context->records++;
    return context->records == 15u ? flush_chunk(context) : 0;
}

static int layer_done(void *opaque, unsigned layer)
{
    run_context *context = (run_context *)opaque;
    uint32_t status;
    if (flush_chunk(context) || host_op(6u, 0u, 0u, zero, &status)) return -1;
    if ((status & 0xffffu) != context->rows * 72u) {
        xil_printf("ERROR ADD layer=%u count=%u expected=%u\r\n", layer,
                   (unsigned)(status & 0xffffu), context->rows * 72u);
        return -1;
    }
    return 0;
}

static uint32_t crc32_byte(uint32_t crc, uint8_t byte)
{
    crc ^= byte;
    for (unsigned bit = 0u; bit < 8u; ++bit)
        crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    return crc;
}

static void send_logits(unsigned position)
{
    const volatile uint8_t *bytes =
        (const volatile uint8_t *)(uintptr_t)MODEL_LOGITS_BASE;
    uint32_t crc = 0xffffffffu;
    Xil_DCacheInvalidateRange((INTPTR)MODEL_LOGITS_BASE, LOGIT_BYTES);
    __asm__ volatile("dsb sy" ::: "memory");
    xil_printf("LOGITS %u %u\r\n", position, LOGIT_BYTES);
    for (unsigned i = 0u; i < LOGIT_BYTES; ++i) {
        uint8_t value = bytes[i];
        XUartPs_SendByte(STDOUT_BASEADDRESS, value);
        crc = crc32_byte(crc, value);
    }
    xil_printf("\r\nLOGITS_END %08x\r\n", crc ^ 0xffffffffu);
}

static int run_block(const uint16_t *tokens, unsigned rows, unsigned start,
                     unsigned emit_logits)
{
    run_context context = {0u, 0u, rows};
    uint64_t began = timer_count();
    if (smollm2_emit_block_with_logits(tokens, rows, start, emit_logits,
                                      issue, layer_done, &context) ||
        flush_chunk(&context)) return -1;
    uint64_t elapsed = timer_count() - began;
    uint64_t frequency = timer_frequency();
    if (!frequency) { xil_printf("ERROR TIMER_FREQUENCY\r\n"); return -1; }
    uint64_t elapsed_us = elapsed * 1000000u / frequency;
    if (elapsed_us > 0xffffffffu) elapsed_us = 0xffffffffu;
    next_position = start + rows;
    xil_printf("BLOCK_DONE %u %u %u %u\r\n", start, next_position,
               context.chunk, (unsigned)elapsed_us);
    if (emit_logits) send_logits(next_position - 1u);
    return 0;
}

static int read_line(char *line, unsigned capacity)
{
    unsigned used = 0u;
    for (;;) {
        unsigned char c = XUartPs_RecvByte(STDIN_BASEADDRESS);
        if (c == '\r') continue;
        if (c == '\n') {
            line[used] = '\0';
            return (int)used;
        }
        if (used + 1u >= capacity) {
            do { c = XUartPs_RecvByte(STDIN_BASEADDRESS); }
            while (c != '\n');
            return -1;
        }
        line[used++] = (char)c;
    }
}

static int next_uint(const char **cursor, unsigned *value)
{
    const char *p = *cursor;
    unsigned result = 0u, digits = 0u;
    while (*p == ' ') ++p;
    while (*p >= '0' && *p <= '9') {
        unsigned digit = (unsigned)(*p - '0');
        if (result > (0xffffffffu - digit) / 10u) return -1;
        result = result * 10u + digit;
        ++p;
        ++digits;
    }
    if (!digits || (*p && *p != ' ')) return -1;
    *cursor = p;
    *value = result;
    return 0;
}

int main(void)
{
    char line[256];
    uint16_t tokens[32];
    xil_printf("SMOLLM2_ISA_INTERACTIVE_V1\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    if (load_model_from_sd()) {
        xil_printf("ERROR SD_MODEL\r\n");
        while (1) {}
    }
    host_seq = (Xil_In32(GPIO_CTL + 8u) >> 31) & 1u;
    xil_printf("READY 1024 32 49152\r\n");
    for (;;) {
        int length = read_line(line, sizeof(line));
        if (length < 0) { xil_printf("ERROR LINE_TOO_LONG\r\n"); continue; }
        if (length == 5 && line[0] == 'R' && line[1] == 'E' &&
            line[2] == 'S' && line[3] == 'E' && line[4] == 'T') {
            next_position = 0u;
            xil_printf("READY 1024 32 49152\r\n");
            continue;
        }
        if (length < 2 || line[0] != 'B' || line[1] != ' ') {
            xil_printf("ERROR COMMAND\r\n");
            continue;
        }
        const char *cursor = line + 2;
        unsigned start, rows, emit_logits, id;
        if (next_uint(&cursor, &start) || next_uint(&cursor, &rows) ||
            next_uint(&cursor, &emit_logits) || start != next_position ||
            rows < 1u || rows > 32u || start + rows > 1024u ||
            emit_logits > 1u) {
            xil_printf("ERROR BLOCK_HEADER expected_start=%u\r\n",
                       next_position);
            continue;
        }
        int bad = 0;
        for (unsigned i = 0u; i < rows; ++i) {
            if (next_uint(&cursor, &id) || id >= 49152u) { bad = 1; break; }
            tokens[i] = (uint16_t)id;
        }
        while (*cursor == ' ') ++cursor;
        if (bad || *cursor) { xil_printf("ERROR TOKEN_IDS\r\n"); continue; }
        if (run_block(tokens, rows, start, emit_logits)) {
            xil_printf("ERROR ISA_EXECUTION\r\n");
            while (1) {}
        }
    }
}
