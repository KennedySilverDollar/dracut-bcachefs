# dracut-bcachefs

An integrated dracut module for using bcachefs as the root filesystem
in a Void Linux (dracut) environment.

bcachefs-tools ships a hook for initramfs-tools, but doesn't include
an integrated module for dracut. This repository fills that gap.

## What it does

- Includes `bcachefs.ko` and its module dependencies (via `instmods`).
- Installs `bcachefs`, `fsck.bcachefs`, `mount.bcachefs` and the
  `64-bcachefs.rules` udev rule.
- Adds an `initqueue/timeout` hook (non-systemd images) that waits once
  more for udev to settle. Unlike dracut's btrfs hook, it does not
  rescan devices.
- Aborts the dracut run if no bcachefs module exists for the target
  kernel (for example after a failed DKMS build), instead of silently
  building an initramfs that cannot mount a bcachefs root.

## Structure

- module.d/70bcachefs/ - dracut module (module-setup.sh,
  bcachefs_timeout.sh)
- xbps/dracut-bcachefs/ - xbps package template
  (files/ is a symlink to ../../module.d, so the module is
  edited in one place only)
- scripts/sync-to-void-packages.sh - copies the module + template
  into a local void-packages checkout for building (build-only;
  never pushed upstream)
- contrib/esp-deploy-sprout.sh - copies a kernel and a verified initramfs
  to the ESP under new names and prints a Sprout TOML entry to append by
  hand. Sprout-specific. UNTESTED: syntax-checked only, never run end to end.
- patches/ - a patch for building bcachefs-tools on musl (see
  patches/README for the exact base commit)
- docs/ - notes from the 2026-10-01 mainline report (mainline.md, musl-userland.md)

## Install (local build)

```
./scripts/sync-to-void-packages.sh /path/to/void-packages
cd /path/to/void-packages
./xbps-src pkg dracut-bcachefs
sudo xbps-install --repository=hostdir/binpkgs dracut-bcachefs
```

(The last command is run from the void-packages directory.)

After installing, regenerate the initramfs explicitly for the target
kernel version and verify with lsinitrd before deploying it to the
path your bootloader actually reads:

```
sudo dracut --force --kver <version> /boot/initramfs-<version>.img
lsinitrd /boot/initramfs-<version>.img | grep -i bcachefs
```

## Verified configuration

One machine, one setup. This is not a compatibility guarantee.

musl (initramfs booted):

| Item | Version |
|---|---|
| OS | Void Linux (musl), x86_64 |
| Kernel | 7.2.8_1 |
| bcachefs module | v1.39.6-2-g772d5cd02021 (DKMS, built from upstream master) |
| bcachefs-tools (in initramfs) | 1.36.1_1 (Void package) |

- An initramfs built with `--add bcachefs --no-hostonly-cmdline` booted
  a bcachefs root read-write with `version_upgrade=none`. That image was
  built with package revision 0.1.0_2, before the missing-module check
  existed.
- Revision 0.1.0_3 (with the check), tested by building into /tmp only:
  - Kernel with a bcachefs module (7.2.8_1): the build succeeds, logs
    the module version, and the image contains bcachefs.ko.zst.
  - Kernel without one (7.2.7_1): dracut stops with
    "installkernel failed in module bcachefs", exits 1, and writes no
    image.

glibc (initramfs build only, not booted):

| Item | Version |
|---|---|
| OS | Void Linux (glibc) in a Bedrock stratum, x86_64 |
| dracut | 112_1 |
| Kernel / module | 7.2.8_1, v1.39.6-2-g772d5cd02021 (shared /lib/modules) |
| bcachefs-tools | 1.36.1_1 (Void package) |

- The module directory was copied into the stratum by hand (identical to
  this repository); the xbps package was not built on glibc.
- Kernel with a bcachefs module (7.2.8_1): the build succeeds and the image
  contains bcachefs.ko.zst, its module dependencies (raid6_pq, xor,
  lz4hc_compress, libchacha, libpoly1305), /usr/bin/bcachefs, the
  fsck/mount symlinks, the udev rule, the timeout hook, and every library
  `ldd` lists for bcachefs.
- Kernel without one (7.2.7_1): dracut stops with
  "installkernel failed in module bcachefs", exits 1, writes no image.

## Notes

- `--no-hostonly-cmdline` does not write `rd.driver.pre=bcachefs` into
  the image. If you use that option on a machine slow enough to hit the
  race the btrfs module guards against, add `rd.driver.pre=bcachefs` to
  the bootloader's kernel options.
- In hostonly mode, dracut stored `root=UUID=` as bcachefs's sub-UUID on
  the verified machine, while booting uses the primary UUID. The
  workaround used was `--no-hostonly-cmdline` with `root=` set in the
  bootloader. The cause was not traced into dracut itself.
- A new kernel needs a bcachefs module built for it. If the DKMS build
  fails, the initramfs build now stops; fix the DKMS build first.
- Running dracut inside a Bedrock stratum also pulls Bedrock's
  /bedrock/cross stubs and firmware into the image (seen on both musl and
  glibc). The image that booted on musl contains them too.

## Not verified

- Booting an initramfs built with revision 0.1.0_3.
- Booting an initramfs built on glibc.
- Building the xbps package on a glibc host.
- Whether an existing /boot/initramfs-<version>.img survives intact when
  the missing-module check aborts a run, and how the Void kernel-install
  hook behaves in that case.
- Multi-device and encrypted bcachefs roots.
- Whether the timeout hook ever runs in practice (it is in the image;
  no boot has hit the timeout).
- Booting an initramfs built with revision 0.1.0_3. An image built with it
  was compared with the image that booted: the bcachefs binary, module,
  udev rule and timeout hook have identical SHA-256 prefixes (first 16 hex
  digits). The only differences found were 8 unversioned lib*.so symlinks
  and device-node timestamps. The booted image and this one were both built
  before the comment edits in module.d/.
- Other distributions.

## Project policy

This project intentionally does not submit changes upstream (to
void-packages, dracut, or bcachefs-tools). It's maintained as an
independent package for personal/research use.

## License

GPL-2.0-or-later, same as dracut's license -- this module's structure
closely follows dracut's own 70btrfs/70dm modules.