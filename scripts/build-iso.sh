#!/usr/bin/env bash
#
# Wrap mkarchiso to produce a TorrentOS ISO at ./out/.
# Assumes scripts/build-pkgs.sh has already populated ./repo/.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="$ROOT/archiso"
WORK="$ROOT/work"
OUT="$ROOT/out"
REPO="$ROOT/repo/x86_64"

log() { printf '\033[1;34m[build-iso]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-iso]\033[0m %s\n' "$*" >&2; exit 1; }

command -v mkarchiso >/dev/null 2>&1 || err "mkarchiso not found — pacman -S archiso"
[[ $EUID -eq 0 ]] || err "mkarchiso must run as root."

[[ -d "$REPO" ]] || err "Local repo $REPO missing. Run scripts/build-pkgs.sh first."
ls "$REPO"/torrentos.db* >/dev/null 2>&1 || err "Repo not indexed. Run scripts/build-pkgs.sh."

# Render pacman.conf with absolute repo path (mkarchiso inherits it).
sed "s|file:///\$repo|file://$REPO|g" \
    "$PROFILE/pacman.conf" > "$PROFILE/pacman.conf.rendered"

mkdir -p "$WORK" "$OUT"
log "Building ISO… (this takes 5-15 min on first run)"
mkarchiso -v \
    -w "$WORK" \
    -o "$OUT" \
    -p "$PROFILE/pacman.conf.rendered" \
    "$PROFILE"

log "ISO produced under $OUT"
ls -lh "$OUT"
