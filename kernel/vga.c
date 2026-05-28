/* TorrentOS — VGA text mode driver
 * Drives the 80x25 character display at memory address 0xB8000.
 * No OS, no library — pure hardware I/O. */

#include "vga.h"
#include "io.h"

/* VGA text buffer lives at a fixed hardware address */
static uint16_t *const vga_buf = (uint16_t *)0xB8000;

static size_t    vga_row;
static size_t    vga_col;
static uint8_t   vga_color;

static inline uint8_t make_color(vga_color_t fg, vga_color_t bg) {
    return (uint8_t)(fg | (bg << 4));
}

static inline uint16_t make_entry(char c, uint8_t color) {
    return (uint16_t)(uint8_t)c | ((uint16_t)color << 8);
}

/* Move the blinking hardware cursor to the current position */
static void update_cursor(void) {
    uint16_t pos = (uint16_t)(vga_row * VGA_WIDTH + vga_col);
    outb(0x3D4, 0x0F); outb(0x3D5, (uint8_t)(pos & 0xFF));
    outb(0x3D4, 0x0E); outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

/* Scroll all lines up by one and blank the last row */
static void scroll(void) {
    uint16_t blank = make_entry(' ', vga_color);
    for (size_t row = 1; row < VGA_HEIGHT; row++)
        for (size_t col = 0; col < VGA_WIDTH; col++)
            vga_buf[(row - 1) * VGA_WIDTH + col] = vga_buf[row * VGA_WIDTH + col];
    for (size_t col = 0; col < VGA_WIDTH; col++)
        vga_buf[(VGA_HEIGHT - 1) * VGA_WIDTH + col] = blank;
    vga_row = VGA_HEIGHT - 1;
}

void vga_init(void) {
    vga_row   = 0;
    vga_col   = 0;
    vga_color = make_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
}

void vga_clear(void) {
    uint16_t blank = make_entry(' ', vga_color);
    for (size_t i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        vga_buf[i] = blank;
    vga_row = 0;
    vga_col = 0;
    update_cursor();
}

void vga_set_color(vga_color_t fg, vga_color_t bg) {
    vga_color = make_color(fg, bg);
}

void vga_putchar(char c) {
    if (c == '\n') {
        vga_col = 0;
        if (++vga_row == VGA_HEIGHT) scroll();
    } else if (c == '\r') {
        vga_col = 0;
    } else if (c == '\b') {
        if (vga_col > 0) {
            vga_col--;
            vga_buf[vga_row * VGA_WIDTH + vga_col] = make_entry(' ', vga_color);
        }
    } else {
        vga_buf[vga_row * VGA_WIDTH + vga_col] = make_entry(c, vga_color);
        if (++vga_col == VGA_WIDTH) {
            vga_col = 0;
            if (++vga_row == VGA_HEIGHT) scroll();
        }
    }
    update_cursor();
}

void vga_print(const char *str) {
    while (*str) vga_putchar(*str++);
}

void vga_println(const char *str) {
    vga_print(str);
    vga_putchar('\n');
}

void vga_print_int(int n) {
    if (n < 0) { vga_putchar('-'); n = -n; }
    if (n >= 10) vga_print_int(n / 10);
    vga_putchar((char)('0' + n % 10));
}
