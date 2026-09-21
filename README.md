# dracut-bcachefs

An integrated dracut module for using bcachefs as the root filesystem
in a Void Linux (dracut) environment.

bcachefs-tools ships a hook for initramfs-tools, but doesn't include
an integrated module for dracut. This repository fills that gap.

## Structure

- module.d/70bcachefs/ - dracut module (module-setup.sh,
  bcachefs_timeout.sh)
- xbps/dracut-bcachefs/ - xbps package template
  (files/ is a symlink to ../../module.d, so the module is
  edited in one place only)
- scripts/sync-to-void-packages.sh - copies the module + template
  into a local void-packages checkout for building (build-only;
  never pushed upstream)
## Install (local build)

./scripts/sync-to-void-packages.sh /path/to/void-packages
cd /path/to/void-packages
./xbps-src pkg dracut-bcachefs
sudo xbps-install --repository=hostdir/binpkgs dracut-bcachefs
After installing, regenerate the initramfs explicitly for the target
kernel version and verify with lsinitrd before deploying it to the
path your bootloader actually reads:
sudo dracut --force --kver <version> /boot/initramfs-<version>.img
lsinitrd /boot/initramfs-<version>.img | grep -i bcachefs

## Status

bcachefs_timeout.sh is modeled on dracut's own
70btrfs/btrfs_timeout.sh but has not yet been diffed line-by-line
against the actual file on a running system. Verify against
/usr/lib/dracut/modules.d/70btrfs/btrfs_timeout.sh before relying
on it in production.

## Project policy

This project intentionally does not submit changes upstream (to
void-packages, dracut, or bcachefs-tools). It's maintained as an
independent package for personal/research use.

## License

GPL-2.0-or-later, same as dracut's license -- this module's structure
closely follows dracut's own 70btrfs/70dm modules