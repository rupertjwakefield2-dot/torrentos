#!/usr/bin/env python3
"""
Send a text command to a running QEMU guest via the monitor socket.
Uses sendkey to type each character into the active guest tty.

Usage: python3 inject-keys.py /tmp/qemu-monitor.sock "command to type"
"""
import socket, time, sys, select

SOCK_PATH = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qemu-monitor.sock"
COMMAND   = sys.argv[2] if len(sys.argv) > 2 else "echo hello"
WAIT_SECS = int(sys.argv[3]) if len(sys.argv) > 3 else 90

# QEMU sendkey names for characters
KEY_MAP = {
    ' ':  'spc',
    '=':  'equal',
    '_':  'underscore',
    '-':  'minus',
    '/':  'slash',
    '.':  'dot',
    '>':  'shift-dot',
    '<':  'shift-comma',
    '|':  'shift-backslash',
    '&':  'shift-7',
    ';':  'semicolon',
    ':':  'shift-semicolon',
    '"':  'shift-apostrophe',
    "'":  'apostrophe',
    '!':  'shift-1',
    '@':  'shift-2',
    '#':  'shift-3',
    '$':  'shift-4',
    '%':  'shift-5',
    '^':  'shift-6',
    '*':  'shift-8',
    '(':  'shift-9',
    ')':  'shift-0',
    '+':  'shift-equal',
    '[':  'bracket_left',
    ']':  'bracket_right',
    '\\': 'backslash',
    ',':  'comma',
    '1':  '1', '2': '2', '3': '3', '4': '4', '5': '5',
    '6':  '6', '7': '7', '8': '8', '9': '9', '0': '0',
}
for c in 'abcdefghijklmnopqrstuvwxyz':
    KEY_MAP[c] = c
for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
    KEY_MAP[c] = f'shift-{c.lower()}'


def monitor_send(s, cmd):
    s.sendall((cmd + '\n').encode())
    time.sleep(0.15)
    # drain response
    ready = select.select([s], [], [], 0.5)
    if ready[0]:
        s.recv(4096)


def connect(path, retries=20):
    for i in range(retries):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(path)
            # drain the banner
            time.sleep(0.3)
            ready = select.select([s], [], [], 1)
            if ready[0]:
                s.recv(4096)
            return s
        except (FileNotFoundError, ConnectionRefusedError):
            print(f"Monitor not ready, retry {i+1}/{retries}...")
            time.sleep(2)
    raise RuntimeError(f"Could not connect to {path}")


print(f"Connecting to QEMU monitor at {SOCK_PATH}...")
s = connect(SOCK_PATH)
print("Connected. Checking VM status...")
monitor_send(s, "info status")

print(f"Waiting {WAIT_SECS}s for guest to finish booting...")
time.sleep(WAIT_SECS)

print(f"Typing: {COMMAND!r}")
for char in COMMAND:
    key = KEY_MAP.get(char)
    if key is None:
        print(f"  WARNING: no key mapping for {char!r}, skipping")
        continue
    monitor_send(s, f"sendkey {key}")

# Press Enter
print("Pressing Enter...")
monitor_send(s, "sendkey ret")

print("Done. Command sent to guest.")
s.close()
