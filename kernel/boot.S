/* TorrentOS — multiboot2 entry point
 * This is the very first code that runs when TorrentOS boots.
 * GRUB loads this, hands control here, and we take over. */

.set MULTIBOOT2_MAGIC,    0xe85250d6
.set MULTIBOOT2_ARCH,     0           /* 32-bit protected mode */
.set HEADER_LENGTH,       (header_end - header_start)
.set CHECKSUM,            -(MULTIBOOT2_MAGIC + MULTIBOOT2_ARCH + HEADER_LENGTH)

/* ── Multiboot2 header (GRUB reads this to identify the kernel) ──────────── */
.section .multiboot, "a"
.align 8
header_start:
    .long MULTIBOOT2_MAGIC
    .long MULTIBOOT2_ARCH
    .long HEADER_LENGTH
    .long CHECKSUM
    /* End tag — required by multiboot2 spec */
    .short 0
    .short 0
    .long 8
header_end:

/* ── Kernel stack (16 KiB) ───────────────────────────────────────────────── */
.section .bss
.align 16
stack_bottom:
    .skip 16384
stack_top:

/* ── Kernel entry point ──────────────────────────────────────────────────── */
.section .text
.global _start
.type _start, @function
_start:
    movl $stack_top, %esp   /* set up the stack */
    pushl $0
    popf                    /* clear EFLAGS */

    /* Pass multiboot2 arguments to kernel_main(magic, info_ptr) */
    pushl %ebx              /* pointer to multiboot2 info structure */
    pushl %eax              /* magic number — should be 0x36d76289 */

    call kernel_main

    /* If kernel_main ever returns, halt the CPU */
.Lhalt:
    cli
    hlt
    jmp .Lhalt
