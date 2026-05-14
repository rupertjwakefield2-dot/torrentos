#!/usr/bin/env bash
# Triggered from /etc/xdg/autostart on first login. Idempotent.
# Prefers the GTK4 wizard; falls back to the bash TUI if it is unavailable.
MARKER="${HOME}/.config/torrentos/first-boot-done"
[[ -f "$MARKER" ]] && exit 0
if [[ -x /usr/bin/torrentos-first-boot-wizard ]]; then
    exec /usr/bin/torrentos-first-boot-wizard
else
    exec /usr/local/bin/torrentos-firstboot
fi
