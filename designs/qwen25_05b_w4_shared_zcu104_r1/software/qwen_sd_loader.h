#ifndef QWEN_SD_LOADER_H
#define QWEN_SD_LOADER_H
#include <stdint.h>
#include <stddef.h>
/* SD1 is logical drive0 in the matching BSP. QWEN.BIN is FAT 8.3. */
int qwen_sd_load(void *destination,size_t bytes,const uint8_t expected[32],void (*log)(const char *));
#endif
