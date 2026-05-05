#!/usr/bin/env bash
#
# Boot the most recently built ISO in QEMU for a smoke test.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$(ls -t "$ROOT"/out/*.iso 2>/dev/null | head -1)" || true
[[ -z "${ISO:-}" ]] && { echo "no ISO under $ROOT/out - build one first" >&2; exit 1; }

QEMU_ARGS=(
    -smp "${QEMU_CPUS:-4}" -m "${QEMU_MEM:-4096}"
    -machine q35
    -drive "file=$ISO,media=cdrom,readonly=on"
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
)

if [[ -r /dev/kvm ]]; then
    QEMU_ARGS=(-enable-kvm -cpu host "${QEMU_ARGS[@]}")
else
    QEMU_ARGS=(-cpu max "${QEMU_ARGS[@]}")
fi

if [[ -f /usr/share/edk2-ovmf/x64/OVMF.fd ]]; then
    QEMU_ARGS=(-bios /usr/share/edk2-ovmf/x64/OVMF.fd "${QEMU_ARGS[@]}")
fi

if [[ "${QEMU_GL:-1}" == "1" ]]; then
    QEMU_ARGS+=(-device virtio-vga-gl -display gtk,gl=on)
else
    QEMU_ARGS+=(-device virtio-vga -display gtk)
fi

if [[ "${QEMU_AUDIO:-1}" == "1" ]]; then
    QEMU_ARGS+=(-audiodev pipewire,id=snd0 -device intel-hda -device hda-output,audiodev=snd0)
fi

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
