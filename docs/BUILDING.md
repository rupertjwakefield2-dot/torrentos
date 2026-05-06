# Building TorrentOS

## Host Requirements

- **An Arch Linux host.** `mkarchiso` requires the Linux kernel and loop devices.
  - Bare metal Arch: ✓ supported
  - Arch in a VM (VirtualBox, Hyper-V, QEMU): ✓ supported
  - WSL2 with Arch Linux: ✓ supported — recommended on Windows
  - macOS or Windows directly: ✗ not supported
- ~15 GB free disk (packages + ISO + work directory)
- Sudo / root access
- Internet access for the first package sync

---

## One-Time Host Setup

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso base-devel git imagemagick qemu-desktop edk2-ovmf
```

If you are using WSL2 Arch, enable systemd first:

```ini
# /etc/wsl.conf
[boot]
systemd=true
```

Then run `wsl --shutdown` from PowerShell and re-open the Arch shell.

---

## Full Build

```bash
git clone https://github.com/rupertjwakefield2-dot/torrentos
cd torrentos

# 1. Build the six custom TorrentOS packages into ./repo/x86_64/
./scripts/build-pkgs.sh

# 2. Optional: generate a high-quality wallpaper (requires ImageMagick).
#    The build script falls back to a tiny placeholder when this is missing.
convert -size 3840x2160 gradient:'#0A1628-#1E6FFF' -blur 0x80 \
    packages/torrentos-theme/wallpaper.png

# 3. Build AUR packages (paru-bin, bibata-cursor-theme-bin, etc.)
./scripts/build-aur.sh

# 4. Build the ISO. Must run as root because mkarchiso needs loop devices.
sudo ./scripts/build-iso.sh

# 5. Smoke-test in QEMU.
./scripts/test-iso.sh
```

The ISO lands in `./out/torrentos-YYYY.MM.DD-x86_64.iso`.

---

## What Gets Built

| Stage | Script | Output |
|-------|--------|--------|
| Custom packages | `build-pkgs.sh` | `./repo/x86_64/torrentos-*.pkg.tar.zst` — indexed as a local pacman repo |
| AUR packages | `build-aur.sh` | `./repo/x86_64/paru-bin-*.pkg.tar.zst` and friends |
| Live ISO | `build-iso.sh` | `./out/torrentos-*.iso` |
| Smoke test | `test-iso.sh` | Boots the newest ISO in QEMU |

### Custom packages

| Package | Contents |
|---------|----------|
| `torrentos-base` | Version file, branding, settings daemon, firstboot bash fallback |
| `torrentos-theme` | GTK/Qt/icon/cursor theme bundle, wallpaper |
| `torrentos-hyprland-config` | All skel dotfiles — Hyprland, Waybar, rofi, swaync, ghostty, zsh, starship, fonts, mimeapps |
| `torrentos-first-boot` | GTK4/libadwaita setup wizard |
| `torrentos-settings` | GTK4/libadwaita settings application |
| `torrentos-tools` | GUI tools — screenshot, system update, help reference |

---

## Iterating Without a Full Rebuild

You do not need to rebuild the ISO for every config change. Boot the ISO, edit
`~/.config/hypr/...` (or any other dotfile) inside the live session, verify it
works, then copy the final changes back to `archiso/airootfs/etc/skel/.config/...`
and rebuild.

For Python settings-app changes: edit files under
`packages/torrentos-settings/src/torrentos_settings/`, then run
`./scripts/build-pkgs.sh` (which rebuilds `torrentos_settings.tar.gz` from source).

---

## Common Issues

**`makepkg: ERROR: Cannot find the strip binary`**
Install `binutils` on your host.

**`mkarchiso: cannot determine which mkinitcpio preset to use`**
Your `packages.x86_64` is missing `mkinitcpio-archiso`. Restore the default entry.

**ISO boots to a black screen in QEMU**
Try `QEMU_GL=0 ./scripts/test-iso.sh`. Hyprland prefers hardware GL; disabling it
falls back to llvmpipe which is slower but renders correctly.

**QEMU says KVM is unavailable**
`test-iso.sh` falls back to software emulation automatically. It is slower (~3–5×)
but sufficient for a basic boot check.

**Hyprland fails to start in the live session**
Hyprland requires hardware GL (EGL/GLES). Without virtio-gl, QEMU falls back to
llvmpipe — expect low FPS but it should still render.

**`file conflict` error during pacstrap**
A file in `airootfs/` is also owned by a custom package. Check the pruning section
in `scripts/ci-build.sh` and add a `rm -f` line for the conflicting path.

**`torrentos-tools` or `torrentos-settings` fails to build**
Run `./scripts/build-pkgs.sh` standalone — it will print the exact makepkg error.
The most common cause is a missing staged source file; check the `stage_*` functions.

---

## Environment Overrides

`build-iso.sh`:
```bash
PROFILE=/tmp/torrentos-profile \
WORK=/tmp/torrentos-work \
OUT=/tmp/torrentos-out \
REPO="$PWD/repo/x86_64" \
sudo -E ./scripts/build-iso.sh
```

`test-iso.sh`:
```bash
QEMU_CPUS=2 QEMU_MEM=3072 QEMU_GL=0 QEMU_AUDIO=0 ./scripts/test-iso.sh
```

---

## Releasing

```bash
# Tag the release
git tag -a v0.4.0 -m "TorrentOS v0.4.0 — Riptide"
git push origin v0.4.0

# GitHub Actions will automatically build the ISO and attach it to the release.
# To upload manually:
sha256sum out/*.iso > out/SHA256SUMS
gh release create v0.4.0 out/*.iso out/SHA256SUMS \
    --title "TorrentOS v0.4.0 — Riptide" \
    --notes-file CHANGELOG.md
```
