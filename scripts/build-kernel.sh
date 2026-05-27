#!/usr/bin/env bash
# ============================================================
# build-kernel.sh — Build linux-torrentos kernel packages
#
# Runs inside an Arch Linux Docker container (privileged not
# required — just needs pacman and makepkg).
#
# Output: /workspace/kernel-packages/*.pkg.tar.zst
#         (linux-torrentos and linux-torrentos-headers)
#
# This is a SEPARATE build from the ISO. The kernel is slow
# to compile (~20-40min). The ISO build downloads the result
# from the kernel-latest GitHub release and installs it from
# a local file — no recompile on every ISO build.
# ============================================================
set -euo pipefail

ROOT="/workspace"
PKG_DIR="$ROOT/packages/linux-torrentos"
OUT_DIR="$ROOT/kernel-packages"
BUILD_USER="builder"

log()  { printf '\033[1;36m[kernel]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[kernel]\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[kernel]\033[0m  %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Run as root (inside the container). makepkg will drop to $BUILD_USER."
command -v makepkg >/dev/null 2>&1 || err "makepkg not found. Are you in an Arch container?"

mkdir -p "$OUT_DIR"

# -----------------------------------------------------------------------
# 1. Install build dependencies
# -----------------------------------------------------------------------
log "Installing build dependencies..."
pacman -Syu --noconfirm --needed \
    bc cpio gettext libelf pahole perl python tar xz zstd \
    base-devel git

# -----------------------------------------------------------------------
# 2. Create an unprivileged build user
#    makepkg refuses root. We create a throwaway user, give it passwordless
#    sudo for pacman (needed for makepkg -s), and build as that user.
# -----------------------------------------------------------------------
if ! id "$BUILD_USER" &>/dev/null; then
    log "Creating build user '$BUILD_USER'..."
    useradd -m -s /bin/bash "$BUILD_USER"
fi

# Give the build user ownership of the package dir copy and output dir
WORK_DIR="/tmp/kernel-build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -r "$PKG_DIR/"* "$WORK_DIR/"
chown -R "$BUILD_USER:$BUILD_USER" "$WORK_DIR" "$OUT_DIR"

# Allow the build user to install packages via sudo (needed during build deps)
echo "$BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> /etc/sudoers

# -----------------------------------------------------------------------
# 3. Build the kernel
#
# -f: force build even if package already exists in PKGDEST
# -d: skip dep check (we installed deps above as root)
# --skippgpcheck: GPG keys may not be in the container's keyring
#                 (kernel.org tarball is verified via .sign + sha256)
# -j$(nproc): parallelise — the container gets all available cores
#
# Note on time: kernel compilation takes 20-40 minutes depending on
# runner hardware. GitHub Actions standard runners have 2 cores; the
# build takes ~35 minutes there. On 4-core runners it's ~20 minutes.
# -----------------------------------------------------------------------
log "Building linux-torrentos (pkgver: $(grep '^pkgver=' "$WORK_DIR/PKGBUILD" | cut -d= -f2))..."
log "This will take 20-40 minutes. Go make a coffee."

sudo -u "$BUILD_USER" bash -c "
    cd '$WORK_DIR'
    MAKEFLAGS='-j\$(nproc)' \
    PKGDEST='$OUT_DIR' \
    makepkg -fd --noconfirm --skippgpcheck 2>&1
"

# -----------------------------------------------------------------------
# 4. Verify output
# -----------------------------------------------------------------------
log "Built packages:"
ls -lh "$OUT_DIR"/*.pkg.tar.zst 2>/dev/null || err "No packages produced — build failed."

# Compute checksums for the release
cd "$OUT_DIR"
sha256sum ./*.pkg.tar.zst > SHA256SUMS
cat SHA256SUMS

log "Done. Kernel packages ready in $OUT_DIR"
