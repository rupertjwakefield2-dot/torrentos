# Building TorrentOS

## Host requirements

- **An Arch Linux host.** `mkarchiso` requires the Linux kernel + loop devices.
  - Bare metal Arch ✓
  - Arch in a VM (VirtualBox/Hyper-V/QEMU) ✓
  - **WSL2 with archlinux** ✓ (recommended on Windows)
  - macOS / Windows directly ✗
- ~10 GB free disk
- Sudo / root access
- Internet (mkarchiso pulls all packages on first run)

## One-time host setup

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso base-devel git qemu-desktop edk2-ovmf
```

If you're using WSL2 Arch, also enable systemd:

```ini
# /etc/wsl.conf
[boot]
systemd=true
```
…then `wsl --shutdown` from PowerShell and reopen the Arch shell.

## Build

```bash
git clone <this-repo> torrentos && cd torrentos

# 1. Build the custom packages into ./repo/x86_64/
./scripts/build-pkgs.sh

# 2. Drop a real wallpaper at packages/torrentos-theme/wallpaper.png
#    (the build script auto-generates a 1px placeholder otherwise)
convert -size 3840x2160 gradient:'#0A1628-#1E6FFF' -blur 0x80 \
    packages/torrentos-theme/wallpaper.png
./scripts/build-pkgs.sh                       # rerun to repackage

# 3. Build the ISO (must be root; mkarchiso requires it)
sudo ./scripts/build-iso.sh

# 4. Smoke-test in QEMU
./scripts/test-iso.sh
```

The ISO lands in `./out/torrentos-YYYY.MM.DD-x86_64.iso`.

## What gets built

| Stage | Output |
|---|---|
| `build-pkgs.sh` | `./repo/x86_64/torrentos-base-*.pkg.tar.zst` and friends, indexed as a pacman repo |
| `build-iso.sh` | `./out/torrentos-*.iso` (~2 GB) |
| `test-iso.sh` | Boots the ISO in QEMU/KVM with virtio-gl |

## Common issues

**`makepkg: ==> ERROR: Cannot find the strip binary`** — install `binutils`.

**`mkarchiso: cannot determine which mkinitcpio preset to use`** — your
`packages.x86_64` is missing `mkinitcpio-archiso`. It's listed; if you edited
the file, restore it.

**ISO boots to a black screen in QEMU** — pass `-device virtio-vga-gl
-display gtk,gl=on` (already in `test-iso.sh`). On NVIDIA hosts, drop `gl=on`.

**Hyprland fails to start in the live session** — Hyprland needs hardware GL.
QEMU without virtio-gl falls back to llvmpipe; expect 5-10 fps but it should
still render.

## Iterating

You don't need to rebuild the ISO to test config changes. Boot the ISO once,
then mount the airootfs read-write inside QEMU and edit `~/.config/hypr/...`
directly. When you're happy, copy the changes back to
`archiso/airootfs/etc/skel/.config/...` and rebuild.

## Releasing

```bash
export TORRENTOS_SIGN_KEY=<your-gpg-keyid>
export TORRENTOS_REPO_DEST=user@repo.torrentos.org:/var/www/repo/x86_64
./scripts/repo-add.sh

# Sign + publish the ISO
sha256sum out/*.iso > out/SHA256SUMS
gpg --detach-sign -u "$TORRENTOS_SIGN_KEY" out/SHA256SUMS
rsync -avh out/ user@dl.torrentos.org:/var/www/dl/
```
