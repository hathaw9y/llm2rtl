ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00100000, LENGTH = 16M }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) } > RAM
 .rodata : { *(.rodata*) } > RAM
 .data : { *(.data*) } > RAM
 .bss (NOLOAD) : { . = ALIGN(16); __bss_start = .; *(.bss*) *(COMMON) . = ALIGN(16); __bss_end = .; } > RAM
 .stack (NOLOAD) : { . = ALIGN(16); . += 0x10000; __stack_top = .; } > RAM
 /DISCARD/ : { *(.comment*) *(.note*) *(.eh_frame*) }
}
