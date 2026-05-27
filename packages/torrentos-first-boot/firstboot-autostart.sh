#!/usr/bin/env bash
# Triggered by exec-once in hyprland.conf on first login. Idempotent.
# Prefers the GTK4 wizard (no terminal needed); falls back to the bash TUI
# opened inside a Ghostty window so the user can actually see and interact with it.
MARKER="${HOME}/.config/torrentos/first-boot-done"
[[ -f "$MARKER" ]] && exit 0
if [[ -x /usr/bin/torrentos-first-boot-wizard ]]; then
    exec /usr/bin/torrentos-first-boot-wizard
else
    # TUI fallback — must run inside a terminal emulator
    exec ghostty \
        --class=ghostty-firstboot \
        --title="TorrentOS Setup" \
        -e /usr/local/bin/torrentos-firstboot
fi
