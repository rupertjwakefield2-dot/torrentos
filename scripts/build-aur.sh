#!/usr/bin/env bash
#
# Build a curated list of AUR packages into the local pacman repo.
# Run as a non-root user (makepkg refuses root). Intended to run on an Arch host.
#
# Outputs: $ROOT/repo/x86_64/<pkg>-<ver>-<rel>-<arch>.pkg.tar.zst
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$ROOT/repo/x86_64"
# Build in /tmp (container-native tmpfs) so setuid binaries work.
# /workspace is a Windows NTFS 9P mount with nosuid, which breaks makepkg -s.
WORK="/tmp/aur-build"
# Pre-downloaded AUR sources (cloned from WSL where network is reliable).
AUR_CACHE="$ROOT/aur-cache"

# AUR packages to bundle into the ISO. Order matters for deps:
#   paru-bin          — prebuilt binary AUR helper (avoids ~20min Rust build under QEMU)
#   libinput-gestures — touchpad gestures (Python)
#   magnus            — screen magnifier (GTK)
AUR_PKGS=(
    paru-bin
    libinput-gestures
    magnus
    bibata-cursor-theme-bin
    google-chrome          # binary repackage of Google's official .deb — no compilation
    # walker-bin needs 'elephant' (AUR Go build) — add back with native x86_64 builder
)

log() { printf '\033[1;34m[build-aur]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-aur]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && err "Do not run as root; makepkg refuses."
command -v makepkg >/dev/null 2>&1 || err "makepkg not found — run on an Arch host."
command -v git     >/dev/null 2>&1 || err "git not found."

mkdir -p "$REPO_DIR" "$WORK"

already_built() {
    local name="$1"
    # Match pkgname-version-release-arch.pkg.tar.zst (any version)
    compgen -G "$REPO_DIR/${name}-*-*-*.pkg.tar.zst" >/dev/null
}

build_aur() {
    local name="$1"
    if already_built "$name"; then
        log "Skipping $name — already in local repo."
        return 0
    fi

    # Use pre-downloaded cache if available (avoids Docker network issues).
    # Fall back to live AUR clone with retries if cache is missing.
    if [[ -d "$AUR_CACHE/$name" ]]; then
        log "Using cached source for $name"
        rm -rf "$WORK/$name"
        cp -r "$AUR_CACHE/$name" "$WORK/$name"
    else
        log "Cloning AUR/$name (no cache — will retry on failure)"
        rm -rf "$WORK/$name"
        local url="https://aur.archlinux.org/${name}.git"
        local attempts=5 delay=30
        for i in $(seq 1 $attempts); do
            git clone --depth=1 "$url" "$WORK/$name" && break
            [[ $i -lt $attempts ]] || err "Failed to clone $name after $attempts attempts."
            log "Attempt $i failed — retrying in ${delay}s..."
            sleep "$delay"; delay=$(( delay * 2 ))
            rm -rf "$WORK/$name"
        done
    fi
    pushd "$WORK/$name" >/dev/null
    log "Building $name"
    # -d: skip dep check (deps pre-installed as root by ci-build.sh)
    # No -s: avoids sudo pacman inside makepkg (nosuid on NTFS mount breaks it)
    makepkg -fd --noconfirm --skippgpcheck
    mv -f ./*.pkg.tar.zst "$REPO_DIR/"
    popd >/dev/null
}

for p in "${AUR_PKGS[@]}"; do
    build_aur "$p"
done

log "Done. AUR packages in $REPO_DIR"
