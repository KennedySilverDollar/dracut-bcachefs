#!/bin/sh
# scripts/sync-tool-void-packages.sh
#
# How to use
# ./scripts/sync-to-void-packages.sh /path/to/void-packages
#
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOID_PACKAGES="${1:?Usage: $0 <path-to-void-packages-checkout>}"
DEST="$VOID_PACKAGES/srcpkgs/dracut-bcachefs"

mkdir -p "$DEST"
cp -v "$REPO_ROOT/xbps/dracut-bcachefs/template" "$DEST/template"
mkdir -p "$DEST/files/70bcachefs"
cp -v "$REPO_ROOT/module.d/70bcachefs/"*.sh "$DEST/files/70bcachefs/"

echo "Sync is completed: $DEST"
echo "How to build:"
echo "cd $VOID_PACKAGES && ./xbps-src pkg dracut-bcachefs"

chomd +x scripts/sync-to-void-packages.sh