#!/usr/bin/env bash
#
# Build all torrentos-* PKGBUILDs into a local pacman repo at ./repo/.
# Run on an Arch host (or in an Arch chroot/WSL2). Idempotent.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$ROOT/repo/x86_64"
AIROOT="$ROOT/archiso/airootfs"

log() { printf '\033[1;34m[build-pkgs]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-pkgs]\033[0m %s\n' "$*" >&2; exit 1; }

command -v makepkg >/dev/null 2>&1 || err "makepkg not found — run on an Arch host."
[[ $EUID -eq 0 ]] && err "Do not run as root; makepkg refuses."

mkdir -p "$REPO_DIR"

# ---- 1. torrentos-base: stage shared sources from airootfs ----
stage_base() {
    local pkg="$ROOT/packages/torrentos-base"
    log "Staging torrentos-base sources from airootfs/"
    cp "$AIROOT/etc/torrentos/version"                          "$pkg/version"
    cp "$AIROOT/etc/torrentos/default-settings.toml"            "$pkg/default-settings.toml"
    cp "$AIROOT/usr/share/torrentos/branding/os-release"        "$pkg/os-release"
    cp "$AIROOT/usr/lib/torrentos/devmode"                      "$pkg/devmode"
    cp "$AIROOT/usr/lib/torrentos/settingsd"                    "$pkg/settingsd"
    cp "$AIROOT/usr/local/bin/torrentos-firstboot"              "$pkg/firstboot"
    cp "$AIROOT/etc/systemd/system/torrentos-settingsd.service" "$pkg/torrentos-settingsd.service"
}

# ---- 2. torrentos-hyprland-config: stage configs from airootfs ----
stage_hyprland_config() {
    local pkg="$ROOT/packages/torrentos-hyprland-config"
    local skel="$AIROOT/etc/skel/.config"
    log "Staging torrentos-hyprland-config sources"
    cp "$skel/hypr/hyprland.conf"     "$pkg/hyprland.conf"
    cp "$skel/hypr/user.conf"         "$pkg/user.conf"
    cp "$skel/hypr/hyprpaper.conf"    "$pkg/hyprpaper.conf"
    cp "$skel/hypr/hyprlock.conf"     "$pkg/hyprlock.conf"
    cp "$skel/hypr/hypridle.conf"     "$pkg/hypridle.conf"
    cp "$skel/waybar/config.jsonc"    "$pkg/waybar-config.jsonc"
    cp "$skel/waybar/style.css"       "$pkg/waybar-style.css"
    cp "$skel/swaync/config.json"     "$pkg/swaync-config.json"
    cp "$skel/ghostty/config"         "$pkg/ghostty-config"
    cp "$skel/starship.toml"          "$pkg/starship.toml"
    cp "$AIROOT/etc/skel/.zshrc"      "$pkg/zshrc"
}

# ---- 3. torrentos-theme: warn if wallpaper.png is missing ----
check_theme() {
    local pkg="$ROOT/packages/torrentos-theme"
    if [[ ! -f "$pkg/wallpaper.png" ]]; then
        log "WARN: $pkg/wallpaper.png missing — generating a 1px placeholder."
        # 1x1 transparent PNG so makepkg succeeds; replace before release.
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfa\xcf\x00\x00\x00\x02\x00\x01\xe5\'\xde\xfc\x00\x00\x00\x00IEND\xaeB`\x82' > "$pkg/wallpaper.png"
    fi
}

build_one() {
    local name="$1"
    local pkgdir="$ROOT/packages/$name"
    log "Building $name"
    pushd "$pkgdir" >/dev/null
    makepkg -f --noconfirm --skipchecksums --skippgpcheck
    mv -f ./*.pkg.tar.* "$REPO_DIR/"
    popd >/dev/null
}

stage_base
stage_hyprland_config
check_theme

build_one torrentos-base
build_one torrentos-theme
build_one torrentos-hyprland-config
build_one torrentos-first-boot

log "Indexing local repo at $REPO_DIR"
rm -f "$REPO_DIR"/torrentos.db* "$REPO_DIR"/torrentos.files*
repo-add "$REPO_DIR/torrentos.db.tar.gz" "$REPO_DIR"/*.pkg.tar.*

log "Done. Local repo: $REPO_DIR"
log "Next: scripts/build-iso.sh"
