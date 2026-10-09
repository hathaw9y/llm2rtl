#include <stdint.h>
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "vectors.h"
#define GPIO_CTL 0xA0000000u
#define GPIO_HI  0xA0010000u
#define GPIO_LO  0xA0020000u
#define POLL_LIMIT 100000000u

static uint32_t prefill_gate_ddr[6144][4] __attribute__((aligned(64)));
static uint32_t prefill_up_ddr[6144][4] __attribute__((aligned(64)));
static uint32_t decode_gate_ddr[192][4] __attribute__((aligned(64)));
static uint32_t decode_up_ddr[192][4] __attribute__((aligned(64)));
static unsigned host_seq;
static const uint32_t zero[4] = {0,0,0,0};

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
        xil_printf("HOST FAIL op=%u bank=%u status=%08x\r\n",op,bank,(unsigned)status);
        return -1;
    }
    return 0;
}
static int record(unsigned index, __uint128_t cmd)
{
    uint32_t words[4];
    for (unsigned i=0;i<4;++i) words[i]=(uint32_t)(cmd>>(32u*i));
    return host_op(1u,0u,index,words,0);
}
static __uint128_t dma_load(unsigned bank,unsigned bytes,uintptr_t addr)
{
    return ((__uint128_t)1u<<124)|((__uint128_t)bank<<120)|
           ((__uint128_t)bytes<<57)|((__uint128_t)(uint32_t)addr<<25);
}
static int wait_done(const char *name)
{
    for (unsigned poll=0;poll<POLL_LIMIT;++poll) {
        uint32_t status=Xil_In32(GPIO_CTL+8u);
        if ((status>>28)&1u) {
            xil_printf("%s ERROR status=%08x\r\n",name,(unsigned)status);
            return -1;
        }
        if ((status>>27)&1u) return 0;
    }
    xil_printf("%s TIMEOUT\r\n",name);
    return -1;
}
static int run_case(unsigned decode)
{
    unsigned rows=decode?1u:32u;
    uintptr_t gate=decode?(uintptr_t)decode_gate_ddr:(uintptr_t)prefill_gate_ddr;
    uintptr_t up=decode?(uintptr_t)decode_up_ddr:(uintptr_t)prefill_up_ddr;
    const uint16_t *expected=decode?decode1_expected_first16:prefill32_expected_first16;
    uint32_t status;
    unsigned mismatches=0;
    if (gate>UINT32_MAX || up>UINT32_MAX) return -1;
    if (record(0u,dma_load(8u,rows*3072u,gate)) ||
        record(1u,dma_load(9u,rows*3072u,up)) ||
        record(2u,((__uint128_t)0xa89au<<112)|rows) ||
        record(3u,0u) || host_op(2u,0u,0u,zero,0) ||
        wait_done(decode?"decode SILU":"prefill32 SILU")) return -1;
    if (host_op(6u,14u,0u,zero,&status)) return -1;
    if ((status&0xffffu)!=rows*192u) {
        xil_printf("SILU write count=%u expected=%u\r\n",(unsigned)(status&0xffffu),rows*192u);
        return -1;
    }
    for (unsigned row=0;row<rows;++row)
      for (unsigned col=0;col<16u;++col) {
        unsigned index=row*16u+col;
        if (host_op(5u,14u,index,zero,&status)) return -1;
        if ((status&0xffffu)!=expected[index]) {
            if (mismatches<8u) xil_printf("SILU row=%u col=%u got=%04x expected=%04x\r\n",
              row,col,(unsigned)(status&0xffffu),expected[index]);
            ++mismatches;
        }
      }
    xil_printf("%s SILU compare=%u mismatches=%u\r\n",
      decode?"decode":"prefill32",rows*16u,mismatches);
    return mismatches?-1:0;
}
int main(void)
{
    xil_printf("SmolLM2-135M BF16 ZCU104 DMA_LOAD+SILU_MUL probe\r\n");
    xil_printf("checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2\r\n");
    xil_printf("app revision 2: wait for dispatcher DONE\r\n");
#define COPY(dst,src,n) for(unsigned i=0;i<(n);++i) for(unsigned j=0;j<4u;++j) (dst)[i][j]=(src)[i][j]
    COPY(prefill_gate_ddr,prefill32_gate_words,6144u);
    COPY(prefill_up_ddr,prefill32_up_words,6144u);
    COPY(decode_gate_ddr,decode1_gate_words,192u);
    COPY(decode_up_ddr,decode1_up_words,192u);
#undef COPY
    Xil_DCacheFlushRange((INTPTR)prefill_gate_ddr,sizeof(prefill_gate_ddr));
    Xil_DCacheFlushRange((INTPTR)prefill_up_ddr,sizeof(prefill_up_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_gate_ddr,sizeof(decode_gate_ddr));
    Xil_DCacheFlushRange((INTPTR)decode_up_ddr,sizeof(decode_up_ddr));
    __asm__ volatile("dsb sy" ::: "memory");
    host_seq=(Xil_In32(GPIO_CTL+8u)>>31)&1u;
    int failed=run_case(0u) || run_case(1u);
    xil_printf(failed?"BOARD SILU_MUL FAIL\r\n":"BOARD SILU_MUL PASS\r\n");
    while(1) {}
    return failed;
}
