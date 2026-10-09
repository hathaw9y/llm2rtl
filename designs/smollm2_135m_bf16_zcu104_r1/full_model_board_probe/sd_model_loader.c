#include <stdint.h>
#include <string.h>
#include "ff.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "address_map.h"
#include "sd_model_loader.h"

#define MODEL_FILE "0:/MODEL.BIN"
#define LOAD_CHUNK (64u * 1024u)
#define MODEL_CRC32 0xdb7d52bbu

static FATFS filesystem;
static uint8_t read_buffer[LOAD_CHUNK] __attribute__((aligned(64)));

static uint32_t crc32_bytes(uint32_t crc, const uint8_t *data, unsigned count)
{
    for (unsigned i = 0; i < count; ++i) {
        crc ^= data[i];
        for (unsigned bit = 0; bit < 8u; ++bit)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc;
}

int load_model_from_sd(void)
{
    FIL file;
    FRESULT result;
    UINT read_count;
    uint32_t crc = 0xffffffffu;
    unsigned loaded = 0u;
    result = f_mount(&filesystem, "0:/", 1u);
    if (result != FR_OK) {
        xil_printf("SD mount failed FRESULT=%u\r\n", (unsigned)result);
        return -1;
    }
    result = f_open(&file, MODEL_FILE, FA_READ);
    if (result != FR_OK) {
        xil_printf("SD open %s failed FRESULT=%u\r\n", MODEL_FILE, (unsigned)result);
        f_mount(0, "0:/", 0u);
        return -1;
    }
    if (f_size(&file) != MODEL_DDR_STATIC_BYTES) {
        xil_printf("SD size=%u expected=%u\r\n", (unsigned)f_size(&file),
                   (unsigned)MODEL_DDR_STATIC_BYTES);
        f_close(&file);
        f_mount(0, "0:/", 0u);
        return -1;
    }
    while (loaded < MODEL_DDR_STATIC_BYTES) {
        unsigned count = MODEL_DDR_STATIC_BYTES - loaded;
        if (count > LOAD_CHUNK) count = LOAD_CHUNK;
        uint8_t *destination = (uint8_t *)(uintptr_t)(MODEL_DDR_BASE + loaded);
        result = f_read(&file, read_buffer, count, &read_count);
        if (result != FR_OK || read_count != count) {
            xil_printf("SD read failed offset=%u FRESULT=%u bytes=%u/%u\r\n",
                       loaded, (unsigned)result, (unsigned)read_count, count);
            f_close(&file);
            f_mount(0, "0:/", 0u);
            return -1;
        }
        crc = crc32_bytes(crc, read_buffer, count);
        memcpy(destination, read_buffer, count);
        Xil_DCacheFlushRange((INTPTR)destination, count);
        loaded += count;
        if ((loaded & ((32u * 1024u * 1024u) - 1u)) == 0u)
            xil_printf("SD model loaded %u/%u bytes\r\n", loaded,
                       (unsigned)MODEL_DDR_STATIC_BYTES);
    }
    result = f_close(&file);
    f_mount(0, "0:/", 0u);
    if (result != FR_OK) {
        xil_printf("SD close failed FRESULT=%u\r\n", (unsigned)result);
        return -1;
    }
    crc ^= 0xffffffffu;
    xil_printf("SD model loaded bytes=%u crc32=%08x\r\n", loaded, crc);
    if (crc != MODEL_CRC32) {
        xil_printf("SD CRC mismatch expected=%08x\r\n", MODEL_CRC32);
        return -1;
    }
    return 0;
}
