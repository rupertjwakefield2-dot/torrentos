#!/usr/bin/env bash
# TorrentOS ISO build script — runs inside the build container.
# Container: ghcr.io/torrentos/builder (Arch-based, amd64).
# Outputs to /workspace/out/torrentos-<version>-x86_64.iso
set -euo pipefail
log() { printf '\033[1;34m[ci]\033[0m %s\n' "$*"; }

log "Disabling pacman sandbox (incompatible with qemu-user emulation)"
# pacman 7.x adds a seccomp sandbox via libalpm that crashes under QEMU TCG.
# Avoid grep (crashes under QEMU TCG): delete any existing DisableSandbox lines
# then add a fresh one after [options] — idempotent.
sed -i '/^DisableSandbox/d' /etc/pacman.conf
sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
sed -i '/^DisableSandbox/d' /workspace/archiso/pacman.conf
sed -i '/^\[options\]/a DisableSandbox' /workspace/archiso/pacman.conf

log "Pacman init + sync"
pacman-key --init >/dev/null 2>&1
pacman -Sy --noconfirm archlinux-keyring >/dev/null
pacman -Syu --noconfirm >/dev/null

log "Installing build deps"
pacman -S --needed --noconfirm \
    archiso base-devel git sudo imagemagick which file \
    grub edk2-shell mtools dosfstools libisoburn squashfs-tools erofs-utils \
    python >/dev/null

log "Creating builder user"
if ! id builder >/dev/null 2>&1; then
    useradd -m -G wheel builder
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
fi
chown -R builder:builder /workspace

log "Generating wallpaper if missing"
if [[ ! -f /workspace/packages/torrentos-theme/wallpaper.png ]] || \
   [[ $(stat -c%s /workspace/packages/torrentos-theme/wallpaper.png 2>/dev/null) -lt 1000 ]]; then
    convert -size 3840x2160 \
        gradient:'#0A1628-#1E6FFF' -blur 0x80 \
        /workspace/packages/torrentos-theme/wallpaper.png || true
    chown builder:builder /workspace/packages/torrentos-theme/wallpaper.png
fi

log "Borrowing bootloader configs from releng profile"
# Wipe & re-copy. Idempotent and avoids the nested-dir trap when cp -r sees an
# existing destination (which happens because the initial scaffold pre-created
# empty syslinux/ and efiboot/ directories).
for d in syslinux grub efiboot; do
    rm -rf "/workspace/archiso/$d"
    cp -r "/usr/share/archiso/configs/releng/$d" "/workspace/archiso/$d"
done

log "Injecting TorrentOS GRUB theme"
GRUB_THEME_SRC="/workspace/archiso/grub-theme"
GRUB_THEME_DST="/workspace/archiso/grub/themes/torrentos"
mkdir -p "$GRUB_THEME_DST"
cp "$GRUB_THEME_SRC/theme.txt" "$GRUB_THEME_DST/theme.txt"
# Generate background.png from wallpaper (ImageMagick already installed above)
bash "$GRUB_THEME_SRC/generate-background.sh" \
    /workspace/packages/torrentos-theme/wallpaper.png 2>/dev/null || true
[[ -f "$GRUB_THEME_SRC/background.png" ]] \
    && cp "$GRUB_THEME_SRC/background.png" "$GRUB_THEME_DST/background.png"
# Wire theme into grub.cfg (appended before the first menuentry)
# Avoid grep (can SIGSEGV under QEMU): use sed to delete+re-insert, idempotent.
GRUB_CFG="/workspace/archiso/grub/grub.cfg"
if [[ -f "$GRUB_CFG" ]]; then
    # Remove any previous theme injection lines, then prepend fresh
    sed -i '/^set theme=/d; /^export theme/d' "$GRUB_CFG"
    sed -i '1s|^|set theme=($root)/grub/themes/torrentos/theme.txt\nexport theme\n\n|' "$GRUB_CFG"
fi

log "Rebranding bootloader menus from Arch Linux to TorrentOS"
# These configs come from releng with Arch branding; rewrite the visible labels.
for f in /workspace/archiso/grub/grub.cfg \
         /workspace/archiso/grub/loopback.cfg \
         /workspace/archiso/syslinux/archiso_sys-linux.cfg \
         /workspace/archiso/syslinux/archiso_pxe-linux.cfg \
         /workspace/archiso/syslinux/archiso_head.cfg \
         /workspace/archiso/syslinux/syslinux.cfg \
         /workspace/archiso/syslinux/archiso_tail.cfg; do
    [[ -f "$f" ]] || continue
    sed -i \
        -e 's/Arch Linux install medium/TorrentOS Live/g' \
        -e 's/Arch Linux/TorrentOS/g' \
        -e 's/Boot Arch Linux/Boot TorrentOS/g' \
        -e 's/archlinux/torrentos/g' \
        "$f"
done

log "Borrowing essential airootfs files from releng (mkinitcpio archiso preset, passwd, etc.)"
# Selective copy: only the files we don't already ship a TorrentOS version of.
# Branding files (motd, issue, os-release, hostname) come from /workspace/archiso/airootfs/.
RELENG_AIROOTFS=/usr/share/archiso/configs/releng/airootfs
mkdir -p /workspace/archiso/airootfs/etc/mkinitcpio.d \
         /workspace/archiso/airootfs/etc/mkinitcpio.conf.d \
         /workspace/archiso/airootfs/etc/modprobe.d \
         /workspace/archiso/airootfs/root
cp -f "$RELENG_AIROOTFS/etc/mkinitcpio.d/linux.preset"        /workspace/archiso/airootfs/etc/mkinitcpio.d/linux.preset
cp -f "$RELENG_AIROOTFS/etc/mkinitcpio.conf.d/archiso.conf"   /workspace/archiso/airootfs/etc/mkinitcpio.conf.d/archiso.conf
cp -f "$RELENG_AIROOTFS/etc/passwd"                            /workspace/archiso/airootfs/etc/passwd
cp -f "$RELENG_AIROOTFS/etc/shadow"                            /workspace/archiso/airootfs/etc/shadow
cp -f "$RELENG_AIROOTFS/etc/gshadow"                           /workspace/archiso/airootfs/etc/gshadow 2>/dev/null || true
cp -f "$RELENG_AIROOTFS/etc/locale.conf"                       /workspace/archiso/airootfs/etc/locale.conf
cp -f "$RELENG_AIROOTFS/etc/modprobe.d/broadcom-wl.conf"       /workspace/archiso/airootfs/etc/modprobe.d/broadcom-wl.conf
# /root/ — copy ONLY files we don't already provide
cp -n "$RELENG_AIROOTFS/root/.automated_script.sh"            /workspace/archiso/airootfs/root/.automated_script.sh 2>/dev/null || true
cp -rn "$RELENG_AIROOTFS/root/.gnupg"                          /workspace/archiso/airootfs/root/.gnupg 2>/dev/null || true
# Don't overwrite our .zprofile (autostart) or .zlogin if we have one
[[ -f /workspace/archiso/airootfs/root/.zprofile ]] || cp -f "$RELENG_AIROOTFS/root/.zlogin" /workspace/archiso/airootfs/root/.zprofile

# Hostname (we ship our own, but ensure it exists)
echo torrentos > /workspace/archiso/airootfs/etc/hostname

log "Building custom packages (as builder)"
cd /workspace
EXPECTED_PKGS=5
if [[ -f /workspace/repo/x86_64/torrentos.db.tar.gz ]] && \
   [[ $(ls /workspace/repo/x86_64/torrentos-*-*-*-any.pkg.tar.zst 2>/dev/null | wc -l) -ge $EXPECTED_PKGS ]]; then
    log "Skipping torrentos-* — local repo already populated with all $EXPECTED_PKGS packages."
else
    sudo -u builder ./scripts/build-pkgs.sh
fi

log "Pre-installing AUR build deps as root (makepkg -s can't use sudo on nosuid NTFS mount)"
pacman -S --needed --noconfirm \
    libinput python-gobject hicolor-icon-theme xdotool \
    gtk4 libadwaita >/dev/null

log "Building AUR packages (paru-bin, libinput-gestures, magnus, bibata, google-chrome) (as builder)"
sudo -u builder ./scripts/build-aur.sh

log "Re-indexing local repo (defends against stale db.tar.gz)"
cd /workspace/repo/x86_64
rm -f torrentos.db* torrentos.files*
sudo -u builder repo-add torrentos.db.tar.gz *.pkg.tar.zst
cd /workspace

log "Staging profile and pruning package-owned paths from airootfs"
# Files that are installed by torrentos-* packages must NOT also be present in
# airootfs/ — pacstrap rejects file conflicts. Build-pkgs.sh staged the canonical
# sources from airootfs into the PKGBUILDs already, so we can safely prune now.
PROFILE_STAGED=/tmp/torrentos-profile
rm -rf "$PROFILE_STAGED"
cp -a /workspace/archiso "$PROFILE_STAGED"
cd "$PROFILE_STAGED/airootfs"
# torrentos-hyprland-config owns these:
rm -rf etc/skel/.config/hypr etc/skel/.config/waybar etc/skel/.config/swaync \
       etc/skel/.config/rofi etc/skel/.config/ghostty \
       etc/skel/.config/starship.toml etc/skel/.zshrc
# torrentos-base owns these:
rm -rf etc/torrentos etc/systemd/system/torrentos-settingsd.service \
       usr/lib/torrentos usr/local/bin/torrentos-firstboot \
       usr/share/torrentos/branding/os-release
# Clean empty parents
find etc/skel -type d -empty -delete 2>/dev/null || true
find etc/systemd -type d -empty -delete 2>/dev/null || true
find usr/share/torrentos -type d -empty -delete 2>/dev/null || true
cd /workspace

log "Building ISO (as root)"
# Patch build-iso.sh's PROFILE pointer for this run
PROFILE="$PROFILE_STAGED" \
WORK=/workspace/work \
OUT=/workspace/out \
REPO=/workspace/repo/x86_64 \
bash -c '
    set -euo pipefail
    sed "s|file:///\$repo|file://$REPO|g" "$PROFILE/pacman.conf" > "$PROFILE/pacman.conf.rendered"
    mkdir -p "$WORK" "$OUT"
    mkarchiso -v -w "$WORK" -o "$OUT" -C "$PROFILE/pacman.conf.rendered" "$PROFILE"
'

log "Done. Artifacts:"
ls -lh /workspace/out/
