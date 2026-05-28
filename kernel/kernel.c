/* TorrentOS kernel — main entry point
 * This is where the OS starts after the bootloader hands over control.
 * Every line is original TorrentOS code. */

#include <stdint.h>
#include <stddef.h>
#include "vga.h"
#include "keyboard.h"
#include "shell.h"

#define MULTIBOOT2_MAGIC 0x36d76289

static void print_splash(void) {
    vga_set_color(VGA_COLOR_BLACK, VGA_COLOR_BLACK);
    vga_clear();

    /* Top padding */
    vga_println("");
    vga_println("");

    /* Logo */
    vga_set_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK);
    vga_println("      ████████╗ ██████╗ ██████╗ ██████╗ ███████╗███╗   ██╗████████╗ ██████╗ ███████╗");
    vga_println("         ██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔════╝");
    vga_println("         ██║   ██║   ██║██████╔╝██████╔╝█████╗  ██╔██╗ ██║   ██║   ██║   ██║███████╗");
    vga_println("         ██║   ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║   ██║   ██║   ██║╚════██║");
    vga_println("         ██║   ╚██████╔╝██║  ██║██║  ██║███████╗██║ ╚████║   ██║   ╚██████╔╝███████║");
    vga_println("         ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚══════╝");

    vga_println("");
    vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
    vga_println("                        v0.1  |  Independent OS Kernel");
    vga_println("                        --------------------------------");
    vga_println("");
    vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    vga_println("  Kernel loaded. Type 'help' to get started.");
    vga_println("");
}

/* kernel_main is called from boot.S with multiboot2 arguments */
void kernel_main(uint32_t magic, uint32_t mb_info) {
    (void)mb_info;  /* not used yet — will be used for memory map in future */

    vga_init();
    print_splash();

    if (magic != MULTIBOOT2_MAGIC) {
        vga_set_color(VGA_COLOR_YELLOW, VGA_COLOR_BLACK);
        vga_println("  Note: unexpected boot magic — some hardware info unavailable.");
        vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    }

    keyboard_init();
    shell_run();

    /* Never reached */
    __asm__ volatile ("cli; hlt");
}
