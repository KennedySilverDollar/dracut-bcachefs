#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# scripts/sync-to-void-packages.sh
#
# Copies this repo's dracut module + xbps template into a local
# void-packages checkout for building only. Never pushed upstream.
#
# Usage:
# ./scripts/sync-to-void-packages.sh /path/to/void-packages
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOID_PACKAGES="${1:?Usage: $0 <path-to-void-packages-checkout>}"
DEST="$VOID_PACKAGES/srcpkgs/dracut-bcachefs"

if [ ! -d "$VOID_PACKAGES/srcpkgs" ]; then
echo "Error: $VOID_PACKAGES does not look like a void-packages checkout (no srcpkgs/)" >&2
exit 1
fi

mkdir -p "$DEST/files/70bcachefs"
cp -v "$REPO_ROOT/xbps/dracut-bcachefs/template" "$DEST/template"
cp -v "$REPO_ROOT/module.d/70bcachefs/"*.sh "$DEST/files/70bcachefs/"
chmod +x "$DEST/files/70bcachefs/"*.sh

echo ""
echo "Sync complete: $DEST"
echo "To build:"
echo " cd $VOID_PACKAGES && ./xbps-src pkg dracut-bcachefs"