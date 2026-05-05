#!/usr/bin/env bash
# TorrentOS — Rofi power menu
# Two modes:
#   Script mode (default): rofi -show power-menu -modi 'power-menu:~/.config/rofi/power-menu.sh'
#   Direct mode:           ~/.config/rofi/power-menu.sh --rofi   (spawns its own rofi window)

ROFI_THEME="$HOME/.config/rofi/torrentos.rasi"

declare -A CMDS=(
    ["󰌾  Lock Screen"]="hyprlock"
    ["󰒲  Sleep"]="systemctl suspend"
    ["󰜉  Restart"]="systemctl reboot"
    ["⏻  Shut Down"]="systemctl poweroff"
    ["󰍃  Log Out"]="hyprctl dispatch exit"
)

# Ordered list so the menu is predictable
ENTRIES=(
    "󰌾  Lock Screen"
    "󰒲  Sleep"
    "󰜉  Restart"
    "⏻  Shut Down"
    "󰍃  Log Out"
)

# ── Direct / --rofi mode ─────────────────────────────────────────────────────
if [[ "$1" == "--rofi" ]]; then
    CHOSEN=$(printf '%s\n' "${ENTRIES[@]}" | \
        rofi -dmenu \
             -p "Power" \
             -theme "$ROFI_THEME" \
             -theme-str '
                window   { width: 300px; }
                listview { lines: 5; scrollbar: false; }
                element  { padding: 10px 16px; font-size: 13px; }
             ' \
             -no-custom)
    [[ -z "$CHOSEN" ]] && exit 0
    eval "${CMDS[$CHOSEN]}"
    exit 0
fi

# ── Script mode (rofi calls with no args → list; with arg → execute) ─────────
if [[ -z "$1" ]]; then
    for entry in "${ENTRIES[@]}"; do
        echo "$entry"
    done
else
    CMD="${CMDS[$1]}"
    [[ -n "$CMD" ]] && exec bash -c "$CMD"
fi
