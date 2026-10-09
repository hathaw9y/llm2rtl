.section .text.start,"ax"
.global _start
_start:
 msr daifset, #15
 msr spsel, #1
 /* Handoff requires cold system reset and generated psu_init before loading ELF. */
 mrs x0, CurrentEL
 cmp x0, #12
 b.eq 3f
 cmp x0, #8
 b.eq 2f
 mrs x1, sctlr_el1
 bic x1, x1, #1
 bic x1, x1, #4
 bic x1, x1, #4096
 msr sctlr_el1, x1
 b 4f
2:
 mrs x1, sctlr_el2
 bic x1, x1, #1
 bic x1, x1, #4
 bic x1, x1, #4096
 msr sctlr_el2, x1
 b 4f
3:
 mrs x1, sctlr_el3
 bic x1, x1, #1
 bic x1, x1, #4
 bic x1, x1, #4096
 msr sctlr_el3, x1
4:
 dsb sy
 isb
 ldr x0, =__stack_top
 mov sp, x0
 ldr x0, =__bss_start
 ldr x1, =__bss_end
5:
 cmp x0, x1
 b.hs 6f
 strb wzr, [x0], #1
 b 5b
6:
 bl main
7:
 wfe
 b 7b
