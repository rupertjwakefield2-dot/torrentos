#!/usr/bin/env bash
# ============================================================
# build-kernel.sh — Build the linux-torrentos kernel packages
#
# Runs inside an Arch Linux Docker container.
# Output: /workspace/kernel-packages/
#         linux-torrentos-*.pkg.tar.zst
#         linux-torrentos-headers-*.pkg.tar.zst
#         SHA256SUMS
# ============================================================
set -euo pipefail

ROOT="/workspace"
PKG_DIR="$ROOT/packages/linux-torrentos"
OUT_DIR="$ROOT/kernel-packages"
BUILD_USER="builder"
WORK_DIR="/tmp/kernel-build"

log()  { printf '\033[1;36m[kernel]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[kernel]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[kernel]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Must run as root (we drop to $BUILD_USER for makepkg)."

# -----------------------------------------------------------------------
# 1. Initialise pacman keyring
#    A fresh Arch container has an uninitialised keyring. pacman -Syu
#    will fail with "signature is unknown trust" without this.
# -----------------------------------------------------------------------
log "Initialising pacman keyring..."
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring

log "Upgrading base system and installing build dependencies..."
pacman -Syu --noconfirm --needed \
    bc cpio curl gettext jq libelf pahole perl python tar xz zstd \
    base-devel git

# -----------------------------------------------------------------------
# 2. Determine the latest stable kernel version from kernel.org
#    We do NOT hardcode pkgver — the kernel moves fast and a stale
#    version number produces a 404 from kernel.org CDN.
#
#    kernel.org publishes a JSON feed of current releases. We pick the
#    first release whose moniker is "stable" (not "longterm" or "mainline").
#    If that fails for any reason, fall back to the version in PKGBUILD.
# -----------------------------------------------------------------------
log "Fetching latest stable kernel version from kernel.org..."
KVER=""
if KVER=$(curl -fsSL --max-time 15 https://www.kernel.org/releases.json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('releases', []):
    if r.get('moniker') in ('stable', 'longterm'):
        print(r['version'])
        break
" 2>/dev/null) && [[ -n "$KVER" ]]; then
    log "Latest stable kernel: ${KVER}"
else
    KVER=$(grep '^pkgver=' "$PKG_DIR/PKGBUILD" | cut -d= -f2)
    warn "Could not fetch kernel version from kernel.org — using PKGBUILD default: ${KVER}"
fi

# -----------------------------------------------------------------------
# 3. Copy PKGBUILD to work dir and patch in the resolved version
# -----------------------------------------------------------------------
mkdir -p "$OUT_DIR" "$WORK_DIR"
cp -r "$PKG_DIR/"* "$WORK_DIR/"

log "Patching pkgver=${KVER} into PKGBUILD..."
sed -i "s/^pkgver=.*/pkgver=${KVER}/" "$WORK_DIR/PKGBUILD"

# Verify the tarball URL will resolve (non-fatal — makepkg will catch it)
TARBALL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KVER%%.*}.x/linux-${KVER}.tar.xz"
log "Kernel source: ${TARBALL_URL}"

# -----------------------------------------------------------------------
# 4. Create the unprivileged build user
#    makepkg hard-refuses to run as root. We create a throwaway user and
#    give it passwordless sudo for pacman (needed by makepkg -s dep check,
#    though we install deps manually so -d skips that).
# -----------------------------------------------------------------------
if ! id "$BUILD_USER" &>/dev/null; then
    log "Creating build user '$BUILD_USER'..."
    useradd -m -s /bin/bash "$BUILD_USER"
fi

chown -R "$BUILD_USER:$BUILD_USER" "$WORK_DIR" "$OUT_DIR"
grep -q "^$BUILD_USER " /etc/sudoers 2>/dev/null || \
    echo "$BUILD_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# -----------------------------------------------------------------------
# 5. Build the kernel
#
#   -f  — force build (overwrite existing package in PKGDEST)
#   -d  — skip dep check (deps installed as root above)
#   -C  — clean build directory before building
#   --noconfirm — non-interactive
#   --skippgpcheck — no .sign file, but belt-and-suspenders
#   MAKEFLAGS — parallelise compilation
#
#   GitHub Actions standard runners: 2 cores → ~35 min
#   GitHub Actions larger runners:   4 cores → ~20 min
# -----------------------------------------------------------------------
NCPU=$(nproc)
log "Building linux-torrentos ${KVER} (using ${NCPU} cores)..."
log "Expected build time: ~$((35 / NCPU + 5))–$((35 / NCPU + 15)) minutes"

sudo -u "$BUILD_USER" env \
    MAKEFLAGS="-j${NCPU}" \
    PKGDEST="$OUT_DIR" \
    bash -c "cd '$WORK_DIR' && makepkg -fdC --noconfirm --skippgpcheck 2>&1"

# -----------------------------------------------------------------------
# 6. Verify and checksum output
# -----------------------------------------------------------------------
log "Build complete. Verifying output..."
shopt -s nullglob
pkgs=("$OUT_DIR"/*.pkg.tar.zst)
[[ ${#pkgs[@]} -ge 2 ]] || err "Expected at least 2 packages (kernel + headers), got ${#pkgs[@]}"

log "Built packages:"
ls -lh "${pkgs[@]}"

cd "$OUT_DIR"
sha256sum ./*.pkg.tar.zst | tee SHA256SUMS

log "Done. Kernel packages are in $OUT_DIR"
