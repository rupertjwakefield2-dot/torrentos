#!/usr/bin/env bash
#
# Wrap mkarchiso to produce a TorrentOS ISO at ./out/.
# Assumes scripts/build-pkgs.sh has already populated ./repo/.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${PROFILE:-$ROOT/archiso}"
WORK="${WORK:-$ROOT/work}"
OUT="${OUT:-$ROOT/out}"
REPO="${REPO:-$ROOT/repo/x86_64}"
RENDERED_CONF="$PROFILE/pacman.conf.rendered"

log() { printf '\033[1;34m[build-iso]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-iso]\033[0m %s\n' "$*" >&2; exit 1; }

command -v mkarchiso >/dev/null 2>&1 || err "mkarchiso not found - pacman -S archiso"
[[ $EUID -eq 0 ]] || err "mkarchiso must run as root."

[[ -f "$PROFILE/pacman.conf" ]] || err "Profile pacman.conf missing: $PROFILE/pacman.conf"
[[ -d "$REPO" ]] || err "Local repo $REPO missing. Run scripts/build-pkgs.sh first."
ls "$REPO"/torrentos.db* >/dev/null 2>&1 || err "Repo not indexed. Run scripts/build-pkgs.sh."
compgen -G "$REPO/*.pkg.tar.*" >/dev/null || err "No packages found in $REPO. Run scripts/build-pkgs.sh first."

cleanup() {
    rm -f "$RENDERED_CONF"
}
trap cleanup EXIT

# Render pacman.conf with absolute repo path. mkarchiso inherits this file.
sed "s|file:///\$repo|file://$REPO|g" \
    "$PROFILE/pacman.conf" > "$RENDERED_CONF"

mkdir -p "$WORK" "$OUT"
log "Building ISO... (this takes 5-15 min on first run)"

# -C is the pacman.conf flag. Do not use -p here; that means extra packages.
mkarchiso -v \
    -w "$WORK" \
    -o "$OUT" \
    -C "$RENDERED_CONF" \
    "$PROFILE"

log "ISO produced under $OUT"
ls -lh "$OUT"
