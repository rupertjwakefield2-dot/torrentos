#!/usr/bin/env bash
# Triggered from /etc/xdg/autostart on first login. Idempotent.
set -euo pipefail
MARKER="${HOME}/.config/torrentos/first-boot-done"
[[ -f "$MARKER" ]] && exit 0
exec /usr/bin/torrentos-first-boot-wizard
