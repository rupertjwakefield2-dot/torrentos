/* TorrentOS — x86 CPU port I/O
 * Direct hardware communication without any OS or library in between. */
#ifndef IO_H
#define IO_H

#include <stdint.h>

/* Write a byte to a hardware I/O port */
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

/* Read a byte from a hardware I/O port */
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

/* Small delay — used after I/O to let hardware settle */
static inline void io_wait(void) {
    outb(0x80, 0);
}

#endif
