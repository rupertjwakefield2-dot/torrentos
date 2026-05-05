#!/usr/bin/env bash
# TorrentOS — Rofi power menu backend
# Called by Rofi's -modi flag: rofi -show power-menu -modi power-menu:~/.config/rofi/power-menu.sh

declare -A CMD=(
    ["⏻  Shut Down"]="systemctl poweroff"
    ["  Restart"]="systemctl reboot"
    ["  Suspend"]="systemctl suspend"
    ["󰌾  Lock Screen"]="hyprlock"
    ["  Log Out"]="hyprctl dispatch exit"
)

# Rofi calls this script with no args to list options, then with the chosen
# option as $1 to execute it.
if [[ -z "$1" ]]; then
    for key in "${!CMD[@]}"; do
        echo "$key"
    done | sort
else
    exec bash -c "${CMD[$1]}"
fi
