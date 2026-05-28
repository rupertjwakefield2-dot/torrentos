#!/usr/bin/env bash
# TorrentOS build script — builds the kernel and a bootable ISO.
set -euo pipefail

log() { printf '\033[1;34m[TorrentOS]\033[0m %s\n' "$*"; }

log "Building kernel..."
make clean
make

log "Building bootable ISO..."
mkdir -p iso/boot/grub
cp out/torrentos.kernel iso/boot/torrentos.kernel
grub-mkrescue -o out/torrentos.iso iso/ 2>/dev/null

log "Done."
ls -lh out/
