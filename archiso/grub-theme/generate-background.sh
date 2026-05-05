#!/usr/bin/env bash
# Generate the GRUB splash background from the TorrentOS wallpaper.
# Outputs a 1920x1080 PNG suitable for GRUB (no alpha, 8-bit RGB).
# Run automatically by ci-build.sh; can also be run manually.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WALLPAPER="${1:-$SCRIPT_DIR/../../packages/torrentos-theme/wallpaper.png}"
OUTPUT="$SCRIPT_DIR/background.png"

if command -v convert >/dev/null 2>&1; then
    if [[ -f "$WALLPAPER" && $(stat -c%s "$WALLPAPER" 2>/dev/null) -gt 1000 ]]; then
        # Scale wallpaper down and flatten to RGB (GRUB can't handle RGBA)
        convert "$WALLPAPER" \
            -resize 1920x1080^ \
            -gravity Center \
            -extent 1920x1080 \
            -type TrueColor \
            -depth 8 \
            PNG24:"$OUTPUT"
        echo "Generated GRUB background from wallpaper."
    else
        # Fallback: generate gradient directly
        convert -size 1920x1080 \
            gradient:'#0A1628-#1E3A6E' \
            -type TrueColor -depth 8 \
            PNG24:"$OUTPUT"
        echo "Generated GRUB background from gradient (wallpaper not found)."
    fi
else
    echo "ImageMagick not found — skipping GRUB background generation." >&2
fi
