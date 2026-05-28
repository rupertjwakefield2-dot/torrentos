/* TorrentOS — command shell
 * Reads input from the keyboard and dispatches commands.
 * Every line of this is original TorrentOS code. */

#include "shell.h"
#include "vga.h"
#include "keyboard.h"
#include "string.h"
#include "io.h"

#define MAX_CMD 256

/* ── Built-in commands ────────────────────────────────────────────────────── */

static void cmd_help(void) {
    vga_set_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK);
    vga_println("TorrentOS commands:");
    vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    vga_println("  help      show this help");
    vga_println("  version   show OS version");
    vga_println("  about     about TorrentOS");
    vga_println("  clear     clear the screen");
    vga_println("  reboot    restart");
    vga_println("  halt      power off");
}

static void cmd_version(void) {
    vga_set_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK);
    vga_println("TorrentOS  v0.1-kernel");
    vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
    vga_println("Independent OS — no Linux, no dependencies.");
    vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
}

static void cmd_about(void) {
    vga_println("");
    vga_set_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK);
    vga_println("  TorrentOS");
    vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    vga_println("  An independent operating system built from scratch.");
    vga_println("  Kernel, drivers, and shell — all original TorrentOS code.");
    vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
    vga_println("  torrentos.org");
    vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    vga_println("");
}

static void cmd_reboot(void) {
    vga_println("Rebooting...");
    /* Send reset pulse via keyboard controller */
    uint8_t val;
    do { val = inb(0x64); } while (val & 0x02);
    outb(0x64, 0xFE);
    /* Fallback: triple fault */
    while (1) __asm__ volatile ("hlt");
}

static void cmd_halt(void) {
    vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
    vga_println("TorrentOS halted.");
    __asm__ volatile ("cli");
    while (1) __asm__ volatile ("hlt");
}

/* ── Command dispatcher ───────────────────────────────────────────────────── */

static void run_command(const char *cmd) {
    /* Skip leading spaces */
    while (*cmd == ' ') cmd++;
    if (!*cmd) return;

    if      (strcmp(cmd, "help")    == 0) cmd_help();
    else if (strcmp(cmd, "version") == 0) cmd_version();
    else if (strcmp(cmd, "about")   == 0) cmd_about();
    else if (strcmp(cmd, "clear")   == 0) vga_clear();
    else if (strcmp(cmd, "reboot")  == 0) cmd_reboot();
    else if (strcmp(cmd, "halt")    == 0) cmd_halt();
    else {
        vga_set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
        vga_print("  Unknown command: ");
        vga_println(cmd);
        vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
        vga_println("  Type 'help' for available commands.");
        vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    }
}

/* ── Main shell loop ──────────────────────────────────────────────────────── */

void shell_run(void) {
    static char buf[MAX_CMD];
    size_t pos = 0;

    while (1) {
        /* Print prompt */
        vga_set_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK);
        vga_print("torrentos");
        vga_set_color(VGA_COLOR_DARK_GREY, VGA_COLOR_BLACK);
        vga_print(" > ");
        vga_set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);

        pos = 0;

        /* Read a line */
        while (1) {
            char c = keyboard_getchar();

            if (c == '\n') {
                vga_putchar('\n');
                buf[pos] = '\0';
                break;
            } else if (c == '\b') {
                if (pos > 0) {
                    pos--;
                    vga_putchar('\b');
                }
            } else if (pos < MAX_CMD - 1) {
                buf[pos++] = c;
                vga_putchar(c);
            }
        }

        vga_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
        run_command(buf);
    }
}
