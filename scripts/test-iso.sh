#!/usr/bin/env bash
#
# Boot the most recently built ISO in QEMU/KVM for a smoke test.
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$(ls -t "$ROOT"/out/*.iso 2>/dev/null | head -1)" || true
[[ -z "${ISO:-}" ]] && { echo "no ISO under $ROOT/out — build one first" >&2; exit 1; }

exec qemu-system-x86_64 \
    -enable-kvm \
    -cpu host -smp 4 -m 4096 \
    -machine q35 \
    -bios /usr/share/edk2-ovmf/x64/OVMF.fd \
    -drive file="$ISO",media=cdrom,readonly=on \
    -device virtio-vga-gl \
    -display gtk,gl=on \
    -audiodev pipewire,id=snd0 \
    -device intel-hda -device hda-output,audiodev=snd0 \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
