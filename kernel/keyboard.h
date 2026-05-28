/* TorrentOS — PS/2 keyboard driver */
#ifndef KEYBOARD_H
#define KEYBOARD_H

void keyboard_init(void);
char keyboard_getchar(void);  /* blocking — waits until a key is pressed */

#endif
