#!/usr/bin/env bash
#
# Sign and publish ./repo/x86_64/ to repo.torrentos.org (or a local mirror).
# Configure DEST via env: TORRENTOS_REPO_DEST=user@host:/var/www/repo/x86_64
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$ROOT/repo/x86_64"

: "${TORRENTOS_REPO_DEST:?Set TORRENTOS_REPO_DEST=user@host:/path}"
: "${TORRENTOS_SIGN_KEY:?Set TORRENTOS_SIGN_KEY to a GPG key id}"

cd "$REPO"
for pkg in *.pkg.tar.*; do
    [[ "$pkg" == *.sig ]] && continue
    [[ -f "$pkg.sig" ]] || gpg --detach-sign --use-agent -u "$TORRENTOS_SIGN_KEY" "$pkg"
done

repo-add --sign --key "$TORRENTOS_SIGN_KEY" \
    "$REPO/torrentos.db.tar.gz" "$REPO"/*.pkg.tar.*

rsync -avh --delete \
    --include='*.pkg.tar.*' --include='*.sig' \
    --include='torrentos.db*' --include='torrentos.files*' \
    --exclude='*' \
    "$REPO/" "$TORRENTOS_REPO_DEST/"

echo "Published to $TORRENTOS_REPO_DEST"
