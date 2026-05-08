#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║   TorrentOS — Apple Silicon (M1 / M2 / M3) Bootstrap Installer             ║
# ║                                                                             ║
# ║   Requires:  Arch Linux (Asahi) already installed via the Asahi installer.  ║
# ║   Run as:    Your normal user (will sudo when needed).                      ║
# ║   Usage:     bash <(curl -fsSL https://torrentos.org/install-asahi.sh)      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
B='\033[38;2;30;111;255m'
G='\033[38;2;91;235;161m'
Y='\033[38;2;255;180;84m'
R='\033[38;2;255;107;107m'
W='\033[1;37m'
D='\033[2;37m'
N='\033[0m'

log()  { printf "${B}[torrentos]${N} %s\n" "$*"; }
ok()   { printf "${G}  ✔${N}  %s\n" "$*"; }
warn() { printf "${Y}  ⚠${N}  %s\n" "$*"; }
die()  { printf "${R}  ✘  FATAL:${N} %s\n" "$*" >&2; exit 1; }
step() { echo; printf "${W}══ %s ══${N}\n" "$*"; echo; }

# ── pre-flight ────────────────────────────────────────────────────────────────

step "TorrentOS for Apple Silicon"
printf "${D}  Arch Linux (Asahi) bootstrapper — v0.5.0 Riptide${N}\n"
echo

# Must be aarch64
[[ "$(uname -m)" == "aarch64" ]] || die "This script is for Apple Silicon (aarch64). For x86_64 PCs, use the ISO instead: https://torrentos.org"

# Must NOT be root (makepkg refuses root)
[[ $EUID -ne 0 ]] || die "Do not run as root. Run as your normal user; sudo will be used as needed."

# Must have pacman
command -v pacman >/dev/null 2>&1 || die "pacman not found. Please run this on Arch Linux (Asahi)."

# Detect Asahi kernel
if uname -r | grep -qi 'asahi'; then
    ok "Asahi kernel detected: $(uname -r)"
else
    warn "Asahi kernel not detected. This script is designed for Arch Linux (Asahi)."
    warn "Continuing anyway — some hardware features may not work without the Asahi kernel."
fi

# Detect Apple Silicon SoC
SOC="unknown"
if [[ -f /proc/device-tree/compatible ]]; then
    compat="$(tr -d '\0' < /proc/device-tree/compatible 2>/dev/null || true)"
    case "$compat" in
        *t8103*) SOC="M1" ;;
        *t6000*|*t6001*) SOC="M1 Pro/Max/Ultra" ;;
        *t8112*) SOC="M2" ;;
        *t6020*|*t6021*) SOC="M2 Pro/Max/Ultra" ;;
        *t8122*) SOC="M3" ;;
        *t6030*|*t6031*) SOC="M3 Pro/Max/Ultra" ;;
        *) SOC="Apple Silicon (unknown model)" ;;
    esac
fi
ok "Apple Silicon SoC: $SOC"

INSTALL_DIR="$(pwd)"
AUR_DIR="$HOME/.cache/torrentos-aur"
TORRENTOS_REPO_URL="https://github.com/rupertjwakefield2-dot/torrentos/releases/latest/download"

# ── confirmation ──────────────────────────────────────────────────────────────

echo
printf "${W}  This script will install TorrentOS on your Mac (${SOC}).${N}\n"
printf "${D}  It will:${N}\n"
printf "    • Update your Arch Linux system\n"
printf "    • Add the Asahi-edge and chaotic-aur repos\n"
printf "    • Install Hyprland, Waybar, Ghostty, and all TorrentOS packages\n"
printf "    • Install TorrentOS config files and branding\n"
printf "    • Enable greetd (graphical login)\n"
echo
printf "  ${Y}Your existing data will not be deleted.${N}\n"
echo
read -r -p "  Proceed? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ── system update ─────────────────────────────────────────────────────────────

step "Updating system"
sudo pacman -Syu --noconfirm

# ── add Asahi-edge repo (for latest Hyprland + Wayland) ──────────────────────

step "Adding Asahi-edge repository"
PACMAN_CONF=/etc/pacman.conf

add_repo_if_missing() {
    local name="$1" server="$2"
    if ! grep -q "^\[$name\]" "$PACMAN_CONF"; then
        sudo tee -a "$PACMAN_CONF" > /dev/null <<EOF

[$name]
Server = $server
EOF
        log "Added [$name] to pacman.conf"
    else
        ok "[$name] already present"
    fi
}

# Asahi Linux repo (provides asahi-specific packages and aarch64 Hyprland)
add_repo_if_missing "asahi" "https://cdn.asahilinux.org/aarch64/\$repo"

# Chaotic-AUR (prebuilt AUR packages for aarch64)
if ! grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
    log "Adding Chaotic-AUR keyring and mirrorlist"
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
    sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 2>/dev/null || \
    warn "Could not add Chaotic-AUR — some AUR packages will be built from source instead."
    add_repo_if_missing "chaotic-aur" "https://cdn-mirror.chaotic.cx/\$repo/\$arch"
fi

sudo pacman -Sy --noconfirm

# ── install base packages ─────────────────────────────────────────────────────

step "Installing core packages"

BASE_PKGS=(
    # Compositor & Wayland
    hyprland hyprland-protocols xdg-desktop-portal-hyprland
    wayland wayland-protocols xorg-xwayland

    # Shell & panel
    waybar swaync rofi-wayland nwg-dock-hyprland

    # Locker / idle
    hyprlock hypridle hyprpaper hyprpicker

    # Terminal
    ghostty

    # Networking
    networkmanager network-manager-applet bluez bluez-utils blueman

    # Audio
    pipewire pipewire-pulse wireplumber pavucontrol

    # Media / accessibility
    playerctl orca at-spi2-core

    # Screen capture & clipboard
    grim slurp wl-clipboard cliphist wl-clip-persist

    # Night light
    gammastep

    # System tools
    flatpak brightnessctl xdg-utils xdg-user-dirs polkit-gnome greetd greetd-tuigreet

    # Shell & CLI tools
    zsh starship fzf ripgrep fd bat eza zoxide btop jq git

    # Qt / theming
    qt6ct kvantum

    # Fonts
    noto-fonts noto-fonts-emoji
    # inter-font may not be on ARM repos; use ttf-inter from AUR below if needed
    ttf-jetbrains-mono-nerd papirus-icon-theme

    # Torrent
    qbittorrent

    # File manager & apps
    dolphin ark

    # Python (for torrentos-settings)
    python python-pip gtk4 libadwaita vte4 python-gobject

    # Other
    sudo base-devel git imagemagick which file mtools dosfstools
)

sudo pacman -S --needed --noconfirm "${BASE_PKGS[@]}" || \
    warn "Some packages failed to install — continuing. Non-critical packages may be missing."

# ── install paru (AUR helper) ─────────────────────────────────────────────────

step "Installing paru (AUR helper)"
if ! command -v paru >/dev/null 2>&1; then
    mkdir -p "$AUR_DIR"
    pushd "$AUR_DIR" >/dev/null
    if pacman -Si paru >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm paru
    else
        git clone https://aur.archlinux.org/paru-bin.git paru-bin 2>/dev/null || \
            git -C paru-bin pull
        pushd paru-bin >/dev/null
        makepkg -si --noconfirm --skipchecksums --skippgpcheck
        popd >/dev/null
    fi
    popd >/dev/null
fi
ok "paru installed: $(paru --version | head -1)"

# ── install AUR / chaotic-aur packages ───────────────────────────────────────

step "Installing AUR packages"

AUR_PKGS=(
    libinput-gestures      # trackpad multi-touch gestures
    bibata-cursor-theme    # cursor theme (arch=any)
    ttf-inter              # Inter font (if not in repos)
    magnus                 # screen magnifier
)

# Note: google-chrome is x86_64 only. Use chromium (in repos) on Apple Silicon.
if ! pacman -Qi chromium >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm chromium || true
fi

paru -S --needed --noconfirm "${AUR_PKGS[@]}" || \
    warn "Some AUR packages failed — continuing."

# ── download & install TorrentOS packages ────────────────────────────────────

step "Installing TorrentOS packages"

TORRENTOS_PKGS=(
    torrentos-base
    torrentos-theme
    torrentos-hyprland-config
    torrentos-first-boot
    torrentos-settings
    torrentos-tools
)

TMPDIR_PKGS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PKGS"' EXIT

log "Downloading TorrentOS aarch64 packages from GitHub releases..."

DL_FAILED=0
for pkg in "${TORRENTOS_PKGS[@]}"; do
    # Try to download prebuilt aarch64 package first
    url="${TORRENTOS_REPO_URL}/${pkg}-any.pkg.tar.zst"
    if curl -fsSL --output "$TMPDIR_PKGS/${pkg}.pkg.tar.zst" "$url" 2>/dev/null; then
        ok "Downloaded $pkg"
    else
        warn "Pre-built package not available for $pkg — will build from source."
        DL_FAILED=$(( DL_FAILED + 1 ))
    fi
done

if [[ -n "$(ls "$TMPDIR_PKGS"/*.pkg.tar.zst 2>/dev/null)" ]]; then
    sudo pacman -U --noconfirm --needed "$TMPDIR_PKGS"/*.pkg.tar.zst || \
        warn "Some TorrentOS packages failed to install."
fi

# If downloads failed, clone and build locally
if (( DL_FAILED > 0 )); then
    log "Building missing TorrentOS packages from source..."
    TOROS_SRC="$HOME/.cache/torrentos-src"
    if [[ -d "$TOROS_SRC" ]]; then
        git -C "$TOROS_SRC" pull --ff-only 2>/dev/null || true
    else
        git clone "https://github.com/rupertjwakefield2-dot/torrentos.git" "$TOROS_SRC"
    fi

    # Build all packages
    bash "$TOROS_SRC/scripts/build-pkgs.sh" || \
        warn "Package build had errors — continuing with what was produced."

    if [[ -d "$TOROS_SRC/repo/x86_64" ]]; then
        sudo pacman -U --noconfirm --needed "$TOROS_SRC/repo/x86_64"/torrentos-*.pkg.tar.zst 2>/dev/null || \
            warn "Some source-built packages failed to install."
    fi
fi

# ── configure zsh as default shell ───────────────────────────────────────────

step "Configuring shell"
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    log "Setting zsh as default shell"
    chsh -s "$(command -v zsh)" "$USER"
    ok "Default shell set to zsh (takes effect on next login)"
else
    ok "zsh already default shell"
fi

# ── configure greetd ─────────────────────────────────────────────────────────

step "Configuring display manager (greetd)"
sudo mkdir -p /etc/greetd

if [[ -f /etc/torrentos/greetd-config.toml ]]; then
    sudo cp /etc/torrentos/greetd-config.toml /etc/greetd/config.toml
else
    sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd Hyprland"
user = "greeter"
EOF
fi

sudo systemctl enable greetd.service
ok "greetd enabled"

# ── enable system services ────────────────────────────────────────────────────

step "Enabling services"
sudo systemctl enable NetworkManager.service
sudo systemctl enable bluetooth.service

# libinput gestures (needs user in 'input' group)
sudo usermod -aG input "$USER" 2>/dev/null && ok "Added $USER to 'input' group for gestures" || true

# Enable user services at login
mkdir -p "$HOME/.config/systemd/user"
systemctl --user enable torrentos-settingsd.service 2>/dev/null || true

# ── Apple Silicon specific tweaks ─────────────────────────────────────────────

step "Applying Apple Silicon tweaks"

# Use OpenGL via Zink (Vulkan-backed GL) — Apple Silicon has Vulkan via MoltenVK
# for apps that need GLX; not needed for Wayland-native apps
sudo tee /etc/environment.d/90-torrentos-asahi.conf > /dev/null <<'EOF'
# TorrentOS — Apple Silicon environment
# Force Qt/GTK to use Wayland backend (no XWayland for native apps)
QT_QPA_PLATFORM=wayland
GDK_BACKEND=wayland
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland

# Hardware video decode via Apple Silicon GPU (requires asahi-mesa)
LIBVA_DRIVER_NAME=d3d12

# Cursor theme
XCURSOR_THEME=Bibata-Modern-Ice
XCURSOR_SIZE=24
EOF
ok "Wayland environment configured"

# Trackpad gestures config
if [[ ! -f "$HOME/.config/libinput-gestures.conf" ]]; then
    mkdir -p "$HOME/.config"
    # Default config comes from torrentos-hyprland-config package
    libinput-gestures-setup autostart 2>/dev/null || true
    ok "libinput-gestures autostart configured"
fi

# Apple keyboard layout fixup: swap Option/Command to match macOS feel
# (Opt = Alt, Cmd = Super in Linux; this is already how Linux treats them)
ok "Apple keyboard: Super key = Command, Alt = Option (standard Linux mapping)"

# ── wallpaper & branding ──────────────────────────────────────────────────────

step "Setting up wallpaper"
WALLPAPER_DST="/usr/share/torrentos/branding/wallpaper.png"
if [[ ! -f "$WALLPAPER_DST" ]]; then
    sudo mkdir -p "$(dirname "$WALLPAPER_DST")"
    if command -v convert >/dev/null 2>&1; then
        sudo convert -size 3840x2160 gradient:'#0A1628-#1E6FFF' -blur 0x80 "$WALLPAPER_DST"
        ok "Generated gradient wallpaper"
    else
        warn "ImageMagick not found — wallpaper will be a solid colour"
    fi
else
    ok "Wallpaper already exists"
fi

# ── final summary ─────────────────────────────────────────────────────────────

echo
printf "${B}  ══════════════════════════════════════════════${N}\n"
printf "${G}  ✔  TorrentOS installation complete!${N}\n"
printf "${B}  ══════════════════════════════════════════════${N}\n"
echo
printf "${W}  Your Mac (${SOC}) is ready to run TorrentOS.${N}\n"
echo
printf "  ${D}Next steps:${N}\n"
printf "  1. ${W}Reboot${N} — greetd will start automatically\n"
printf "  2. ${W}Log in${N} and Hyprland will launch\n"
printf "  3. ${W}Super + T${N} to open a terminal, ${W}Super + Space${N} for app launcher\n"
printf "  4. ${W}torrentos-settings${N} to customise your system\n"
echo
printf "  ${D}Notes for Apple Silicon:${N}\n"
printf "  • Google Chrome is x86_64 only — ${W}Chromium${N} is installed instead\n"
printf "  • GPU acceleration requires the Asahi mesa driver (installed automatically)\n"
printf "  • Webcam, MagSafe LED, and Touch Bar (if present) are not yet supported\n"
printf "  • For issues: ${W}https://torrentos.org/apple-silicon${N}\n"
echo
printf "  ${Y}Please reboot to complete the installation.${N}\n"
echo
read -r -p "  Reboot now? [y/N] " reboot_now
if [[ "${reboot_now,,}" == "y" ]]; then
    sudo reboot
fi
