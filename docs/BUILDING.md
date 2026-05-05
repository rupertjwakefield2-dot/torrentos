# Building TorrentOS

## Host Requirements

- **An Arch Linux host.** `mkarchiso` requires the Linux kernel and loop devices.
- Bare metal Arch: supported
- Arch in a VM (VirtualBox, Hyper-V, QEMU): supported
- WSL2 with Arch Linux: supported, and recommended on Windows
- macOS or Windows directly: not supported
- About 10 GB free disk
- Sudo/root access
- Internet access for the first package sync

## One-Time Host Setup

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso base-devel git qemu-desktop edk2-ovmf
```

If you are using WSL2 Arch, enable systemd:

```ini
# /etc/wsl.conf
[boot]
systemd=true
```

Then run `wsl --shutdown` from PowerShell and reopen the Arch shell.

## Build

```bash
git clone <this-repo> torrentos
cd torrentos

# 1. Build the custom packages into ./repo/x86_64/
./scripts/build-pkgs.sh

# 2. Optional: drop a real wallpaper at packages/torrentos-theme/wallpaper.png.
#    The build script creates a small placeholder when it is missing.
convert -size 3840x2160 gradient:'#0A1628-#1E6FFF' -blur 0x80 \
    packages/torrentos-theme/wallpaper.png
./scripts/build-pkgs.sh

# 3. Build the ISO. This must run as root because mkarchiso needs loop devices.
sudo ./scripts/build-iso.sh

# 4. Smoke-test in QEMU.
./scripts/test-iso.sh
```

The ISO lands in `./out/torrentos-YYYY.MM.DD-x86_64.iso`.

## What Gets Built

| Stage | Output |
|---|---|
| `build-pkgs.sh` | `./repo/x86_64/torrentos-base-*.pkg.tar.zst` and friends, indexed as a pacman repo |
| `build-aur.sh` | AUR packages required by the live image, copied into `./repo/x86_64/` |
| `build-iso.sh` | `./out/torrentos-*.iso` |
| `test-iso.sh` | Boots the newest ISO in QEMU |

## Common Issues

**`makepkg: ==> ERROR: Cannot find the strip binary`** - install `binutils`.

**`mkarchiso: cannot determine which mkinitcpio preset to use`** - your
`packages.x86_64` is missing `mkinitcpio-archiso`. It is listed by default; if
you edited the file, restore it.

**ISO boots to a black screen in QEMU** - try `QEMU_GL=0 ./scripts/test-iso.sh`.
Hyprland prefers hardware GL, but disabling GL is useful when the host graphics
stack is unhappy.

**QEMU says KVM is unavailable** - `test-iso.sh` now falls back to software
emulation automatically. It is slower, but good enough for a basic boot check.

**Hyprland fails to start in the live session** - Hyprland needs hardware GL.
QEMU without virtio-gl can fall back to llvmpipe; expect low FPS, but it should
still render.

## Iterating

You do not need to rebuild the ISO for every config experiment. Boot the ISO,
edit `~/.config/hypr/...` inside the live session, then copy the final changes
back to `archiso/airootfs/etc/skel/.config/...` and rebuild.

## Useful Overrides

`build-iso.sh` accepts these environment overrides:

```bash
PROFILE=/tmp/torrentos-profile \
WORK=/tmp/torrentos-work \
OUT=/tmp/torrentos-out \
REPO="$PWD/repo/x86_64" \
sudo -E ./scripts/build-iso.sh
```

`test-iso.sh` accepts these environment overrides:

```bash
QEMU_CPUS=2 QEMU_MEM=3072 QEMU_GL=0 QEMU_AUDIO=0 ./scripts/test-iso.sh
```

## Releasing

```bash
export TORRENTOS_SIGN_KEY=<your-gpg-keyid>
export TORRENTOS_REPO_DEST=user@repo.torrentos.org:/var/www/repo/x86_64
./scripts/repo-add.sh

sha256sum out/*.iso > out/SHA256SUMS
gpg --detach-sign -u "$TORRENTOS_SIGN_KEY" out/SHA256SUMS
rsync -avh out/ user@dl.torrentos.org:/var/www/dl/
```
