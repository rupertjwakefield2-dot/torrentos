#!/usr/bin/env bash
# TorrentOS — Rofi power menu
# Two modes:
#   Script mode (default): rofi -show power-menu -modi 'power-menu:~/.config/rofi/power-menu.sh'
#   Direct mode:           ~/.config/rofi/power-menu.sh --rofi   (spawns its own rofi window)

ROFI_THEME="$HOME/.config/rofi/torrentos.rasi"

# Check if hibernate is available (swap must exist and kernel supports it)
_can_hibernate() {
    [[ -f /sys/power/state ]] && grep -q disk /sys/power/state 2>/dev/null \
        && (swapon --show --noheadings 2>/dev/null | grep -q .)
}

declare -A CMDS=(
    ["󰌾  Lock Screen"]="hyprlock"
    ["󰒲  Sleep"]="systemctl suspend"
    ["󰒾  Hibernate"]="systemctl hibernate"
    ["󰜉  Restart"]="systemctl reboot"
    ["⏻  Shut Down"]="systemctl poweroff"
    ["󰍃  Log Out"]="hyprctl dispatch exit"
)

# Build ordered entry list, conditionally including hibernate
ENTRIES=(
    "󰌾  Lock Screen"
    "󰒲  Sleep"
)
_can_hibernate && ENTRIES+=("󰒾  Hibernate")
ENTRIES+=(
    "󰜉  Restart"
    "⏻  Shut Down"
    "󰍃  Log Out"
)

# ── Direct / --rofi mode ─────────────────────────────────────────────────────
if [[ "${1:-}" == "--rofi" ]]; then
    CHOSEN=$(printf '%s\n' "${ENTRIES[@]}" | \
        rofi -dmenu \
             -p "⏻  Power" \
             -theme "$ROFI_THEME" \
             -theme-str '
                window   { width: 300px; }
                listview { lines: 6; scrollbar: false; }
                element  { padding: 10px 16px; }
             ' \
             -no-custom)
    [[ -z "$CHOSEN" ]] && exit 0
    CMD="${CMDS[$CHOSEN]}"
    [[ -n "$CMD" ]] && exec bash -c "$CMD"
    exit 0
fi

# ── Script mode (rofi calls with no args → list; with arg → execute) ─────────
if [[ -z "${1:-}" ]]; then
    for entry in "${ENTRIES[@]}"; do
        echo "$entry"
    done
else
    CMD="${CMDS[$1]:-}"
    [[ -n "$CMD" ]] && exec bash -c "$CMD"
fi
