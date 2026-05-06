#!/usr/bin/env bash
#
# Build all torrentos-* PKGBUILDs into a local pacman repo at ./repo/.
# Run on an Arch host, Arch chroot, or Arch WSL2 instance. Idempotent.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$ROOT/repo/x86_64"
AIROOT="$ROOT/archiso/airootfs"

log() { printf '\033[1;34m[build-pkgs]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-pkgs]\033[0m %s\n' "$*" >&2; exit 1; }

require_file() {
    [[ -f "$1" ]] || err "Missing staged source: $1"
}

command -v makepkg >/dev/null 2>&1 || err "makepkg not found - run on an Arch host."
command -v repo-add >/dev/null 2>&1 || err "repo-add not found - install pacman."
[[ $EUID -eq 0 ]] && err "Do not run as root; makepkg refuses."

mkdir -p "$REPO_DIR"

# 1. torrentos-base: stage shared sources from airootfs.
stage_base() {
    local pkg="$ROOT/packages/torrentos-base"
    log "Staging torrentos-base sources from airootfs/"

    require_file "$AIROOT/etc/torrentos/version"
    require_file "$AIROOT/etc/torrentos/default-settings.toml"
    require_file "$AIROOT/usr/share/torrentos/branding/os-release"
    require_file "$AIROOT/usr/lib/torrentos/devmode"
    require_file "$AIROOT/usr/lib/torrentos/settingsd"
    require_file "$AIROOT/usr/local/bin/torrentos-firstboot"
    require_file "$AIROOT/etc/systemd/system/torrentos-settingsd.service"
    require_file "$AIROOT/etc/greetd/config.toml"

    cp "$AIROOT/etc/torrentos/version"                          "$pkg/version"
    cp "$AIROOT/etc/torrentos/default-settings.toml"            "$pkg/default-settings.toml"
    cp "$AIROOT/usr/share/torrentos/branding/os-release"        "$pkg/os-release"
    cp "$AIROOT/usr/lib/torrentos/devmode"                      "$pkg/devmode"
    cp "$AIROOT/usr/lib/torrentos/settingsd"                    "$pkg/settingsd"
    cp "$AIROOT/usr/local/bin/torrentos-firstboot"              "$pkg/firstboot"
    cp "$AIROOT/etc/systemd/system/torrentos-settingsd.service" "$pkg/torrentos-settingsd.service"
    cp "$AIROOT/etc/greetd/config.toml"                         "$pkg/greetd-config.toml"
}

# 2. torrentos-hyprland-config: stage configs from airootfs.
stage_hyprland_config() {
    local pkg="$ROOT/packages/torrentos-hyprland-config"
    local skel="$AIROOT/etc/skel/.config"
    log "Staging torrentos-hyprland-config sources"

    require_file "$skel/hypr/hyprland.conf"
    require_file "$skel/hypr/user.conf"
    require_file "$skel/hypr/hyprpaper.conf"
    require_file "$skel/hypr/hyprlock.conf"
    require_file "$skel/hypr/hypridle.conf"
    require_file "$skel/waybar/config.jsonc"
    require_file "$skel/waybar/style.css"
    require_file "$skel/swaync/config.json"
    require_file "$skel/swaync/style.css"
    require_file "$skel/rofi/torrentos.rasi"
    require_file "$skel/rofi/power-menu.sh"
    require_file "$skel/ghostty/config"
    require_file "$skel/starship.toml"
    require_file "$AIROOT/etc/skel/.zshrc"
    require_file "$skel/nwg-dock-hyprland/style.css"
    require_file "$skel/gtk-3.0/settings.ini"
    require_file "$skel/gtk-4.0/settings.ini"
    require_file "$skel/fontconfig/fonts.conf"
    require_file "$skel/mimeapps.list"
    require_file "$skel/user-dirs.dirs"
    require_file "$skel/qt6ct/qt6ct.conf"
    require_file "$skel/libinput-gestures.conf"

    cp "$skel/hypr/hyprland.conf"                 "$pkg/hyprland.conf"
    cp "$skel/hypr/user.conf"                     "$pkg/user.conf"
    cp "$skel/hypr/hyprpaper.conf"                "$pkg/hyprpaper.conf"
    cp "$skel/hypr/hyprlock.conf"                 "$pkg/hyprlock.conf"
    cp "$skel/hypr/hypridle.conf"                 "$pkg/hypridle.conf"
    cp "$skel/waybar/config.jsonc"                "$pkg/waybar-config.jsonc"
    cp "$skel/waybar/style.css"                   "$pkg/waybar-style.css"
    cp "$skel/swaync/config.json"                 "$pkg/swaync-config.json"
    cp "$skel/swaync/style.css"                   "$pkg/swaync-style.css"
    cp "$skel/rofi/torrentos.rasi"                "$pkg/rofi-torrentos.rasi"
    cp "$skel/rofi/power-menu.sh"                 "$pkg/rofi-power-menu.sh"
    cp "$skel/ghostty/config"                     "$pkg/ghostty-config"
    cp "$skel/starship.toml"                      "$pkg/starship.toml"
    cp "$AIROOT/etc/skel/.zshrc"                  "$pkg/zshrc"
    cp "$skel/nwg-dock-hyprland/style.css"        "$pkg/nwg-dock-style.css"
    cp "$skel/gtk-3.0/settings.ini"               "$pkg/gtk3-settings.ini"
    cp "$skel/gtk-4.0/settings.ini"               "$pkg/gtk4-settings.ini"
    cp "$skel/fontconfig/fonts.conf"              "$pkg/fonts.conf"
    cp "$skel/mimeapps.list"                      "$pkg/mimeapps.list"
    cp "$skel/user-dirs.dirs"                     "$pkg/user-dirs.dirs"
    cp "$skel/qt6ct/qt6ct.conf"                   "$pkg/qt6ct.conf"
    cp "$skel/libinput-gestures.conf"             "$pkg/libinput-gestures.conf"
}

# 3. torrentos-settings: stage Python package, launcher, and assets.
stage_settings() {
    local pkg="$ROOT/packages/torrentos-settings"
    log "Staging torrentos-settings sources"

    require_file "$pkg/bin/torrentos-settings"
    require_file "$pkg/data/torrentos-settings.desktop"
    require_file "$pkg/data/torrentos-settings.svg"
    [[ -d "$pkg/src/torrentos_settings" ]] || err "Missing staged source directory: $pkg/src/torrentos_settings"

    cp -f "$pkg/bin/torrentos-settings"          "$pkg/torrentos-settings"
    cp -f "$pkg/data/torrentos-settings.desktop" "$pkg/torrentos-settings.desktop"
    cp -f "$pkg/data/torrentos-settings.svg"     "$pkg/torrentos-settings.svg"

    rm -f "$pkg/torrentos_settings.tar" "$pkg/torrentos_settings.tar.gz"
    (cd "$pkg/src" && tar -czf "$pkg/torrentos_settings.tar.gz" torrentos_settings)
    [[ -s "$pkg/torrentos_settings.tar.gz" ]] || err "Failed to create torrentos_settings.tar.gz"
}

# 4. torrentos-tools: stage GUI tool scripts and desktop entries.
stage_tools() {
    local pkg="$ROOT/packages/torrentos-tools"
    local bin="$AIROOT/usr/local/bin"
    local apps="$AIROOT/usr/share/applications"
    log "Staging torrentos-tools sources"

    require_file "$bin/torrentos-update-gui"
    require_file "$bin/torrentos-screenshot"
    require_file "$bin/torrentos-help"
    require_file "$apps/torrentos-update.desktop"
    require_file "$apps/torrentos-screenshot.desktop"
    require_file "$apps/torrentos-help.desktop"

    cp "$bin/torrentos-update-gui"           "$pkg/torrentos-update-gui"
    cp "$bin/torrentos-screenshot"           "$pkg/torrentos-screenshot"
    cp "$bin/torrentos-help"                 "$pkg/torrentos-help"
    cp "$apps/torrentos-update.desktop"      "$pkg/torrentos-update-gui.desktop"
    cp "$apps/torrentos-screenshot.desktop"  "$pkg/torrentos-screenshot.desktop"
    cp "$apps/torrentos-help.desktop"        "$pkg/torrentos-help.desktop"
}

# 5. torrentos-theme: ensure wallpaper.png exists.
check_theme() {
    local pkg="$ROOT/packages/torrentos-theme"
    if [[ ! -f "$pkg/wallpaper.png" ]]; then
        if command -v magick >/dev/null 2>&1; then
            log "WARN: $pkg/wallpaper.png missing - generating a placeholder via ImageMagick."
            magick -size 256x256 gradient:'#0A1628-#1E6FFF' "$pkg/wallpaper.png"
        elif command -v convert >/dev/null 2>&1; then
            log "WARN: $pkg/wallpaper.png missing - generating a placeholder via ImageMagick."
            convert -size 256x256 gradient:'#0A1628-#1E6FFF' "$pkg/wallpaper.png"
        else
            log "WARN: $pkg/wallpaper.png missing - writing a tiny built-in placeholder."
            base64 -d > "$pkg/wallpaper.png" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l4f6qAAAAABJRU5ErkJggg==
PNG
        fi
    fi
}

build_one() {
    local name="$1"
    local pkgdir="$ROOT/packages/$name"
    log "Building $name"

    pushd "$pkgdir" >/dev/null
    rm -f ./*.pkg.tar.*
    makepkg -f --noconfirm --skipchecksums --skippgpcheck --nodeps
    compgen -G "./*.pkg.tar.*" >/dev/null || err "makepkg produced no package for $name"
    mv -f ./*.pkg.tar.* "$REPO_DIR/"
    popd >/dev/null
}

stage_base
stage_hyprland_config
stage_settings
stage_tools
check_theme

build_one torrentos-base
build_one torrentos-theme
build_one torrentos-hyprland-config
build_one torrentos-first-boot
build_one torrentos-settings
build_one torrentos-tools

log "Indexing local repo at $REPO_DIR"
rm -f "$REPO_DIR"/torrentos.db* "$REPO_DIR"/torrentos.files*
repo-add "$REPO_DIR/torrentos.db.tar.gz" "$REPO_DIR"/*.pkg.tar.*

log "Done. Local repo: $REPO_DIR"
log "Next: scripts/build-iso.sh"
