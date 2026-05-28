/* TorrentOS kernel linker script
 * Lays out the kernel in memory starting at 1 MiB (0x100000).
 * The first 1 MiB is reserved for BIOS, hardware, and bootloader. */

ENTRY(_start)

SECTIONS {
    . = 1M;

    /* Executable code — multiboot header must come first */
    .text BLOCK(4K) : ALIGN(4K) {
        *(.multiboot)
        *(.text)
    }

    /* Read-only data (string literals, constants) */
    .rodata BLOCK(4K) : ALIGN(4K) {
        *(.rodata)
    }

    /* Initialised read-write data */
    .data BLOCK(4K) : ALIGN(4K) {
        *(.data)
    }

    /* Zero-initialised data and stack */
    .bss BLOCK(4K) : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }
}
