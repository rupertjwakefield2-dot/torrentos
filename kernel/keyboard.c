/* TorrentOS — PS/2 keyboard driver
 * Reads directly from hardware port 0x60 — no OS, no interrupts, no library. */

#include "keyboard.h"
#include "io.h"
#include <stdint.h>

#define KB_DATA    0x60   /* keyboard data port */
#define KB_STATUS  0x64   /* keyboard status port */

/* Scancode set 1 → ASCII (unshifted) */
static const char sc_normal[] = {
/*00*/  0,    0,  '1','2','3','4','5','6','7','8','9','0','-','=','\b',
/*0F*/ '\t', 'q','w','e','r','t','y','u','i','o','p','[',']','\n',
/*1D*/  0,   'a','s','d','f','g','h','j','k','l',';','\'','`',
/*2A*/  0,  '\\','z','x','c','v','b','n','m',',','.','/', 0,
/*37*/ '*',   0,  ' '
};

/* Scancode set 1 → ASCII (shifted) */
static const char sc_shift[] = {
/*00*/  0,    0,  '!','@','#','$','%','^','&','*','(',')','_','+','\b',
/*0F*/ '\t', 'Q','W','E','R','T','Y','U','I','O','P','{','}','\n',
/*1D*/  0,   'A','S','D','F','G','H','J','K','L',':','"','~',
/*2A*/  0,   '|','Z','X','C','V','B','N','M','<','>','?', 0,
/*37*/ '*',   0,  ' '
};

static int shift = 0;
static int caps  = 0;

void keyboard_init(void) {
    /* Drain any pending bytes in the keyboard buffer */
    while (inb(KB_STATUS) & 0x01)
        inb(KB_DATA);
    shift = 0;
    caps  = 0;
}

char keyboard_getchar(void) {
    while (1) {
        /* Wait for keyboard output buffer to be full (bit 0 of status) */
        while (!(inb(KB_STATUS) & 0x01));

        uint8_t sc = inb(KB_DATA);

        /* Key release: bit 7 set — track shift state */
        if (sc & 0x80) {
            uint8_t rel = sc & 0x7F;
            if (rel == 0x2A || rel == 0x36) shift = 0;
            continue;
        }

        /* Shift pressed */
        if (sc == 0x2A || sc == 0x36) { shift = 1; continue; }

        /* Caps Lock toggle */
        if (sc == 0x3A) { caps ^= 1; continue; }

        /* Ignore extended scancodes (0xE0 prefix) */
        if (sc == 0xE0) continue;

        /* Map scancode to character */
        if (sc >= sizeof(sc_normal)) continue;

        char c = shift ? sc_shift[sc] : sc_normal[sc];
        if (!c) continue;

        /* Apply caps lock to letters */
        if (caps && c >= 'a' && c <= 'z') c = (char)(c - 32);
        if (caps && c >= 'A' && c <= 'Z') c = (char)(c + 32);

        return c;
    }
}
