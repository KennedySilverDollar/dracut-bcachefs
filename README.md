# dracut-bcachefs

An integrated dracut module for using bcachefs as the root filesystem
in a Void Linux (dracut) environment.

bcachefs-tools ships a hook for initramfs-tools, but doesn't include
an integrated module for dracut. This repository fills that gap.

## Structure

- `module.d/70bcachefs/` - dracut module
- `xbps/dracut-bcachefs/` - xbps package template
- `scripts/sync-to-void-packages.sh` - sync script for a local
  void-packages checkout

## Install (local build)

See `xbps/dracut-bcachefs/template` and
`scripts/sync-to-void-packages.sh` for details.

## License

GPL-2.0-or-later, same as dracut's license.