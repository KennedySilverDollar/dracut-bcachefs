# Running bcachefs on a new mainline kernel (Void)

Record of one setup, from a report dated 2026-10-01. Commands are as logged
there. Nothing here is a compatibility guarantee.

Setup: Void Linux (musl), kernel 7.2.8_1, bcachefs root on NVMe, on-disk
format 1.39, a bootloader that loads kernel and initramfs from the ESP.

## 1. Principle

A new kernel needs a bcachefs module built for it. Void's bcachefs-dkms 1.36.1
did not build against 7.2.8_1. Upstream master did, because it carries
compatibility code for both old and new kernel APIs.

The 1.36.1 build failed on these API changes (7.2.8 headers):

| Old API used by 1.36.1 | New API in 7.2.8 headers |
|---|---|
| xor_blocks(), MAX_XOR_BLOCKS | xor_gen(dest, srcs, src_cnt, bytes) |
| raid6_call.gen_syndrome() | raid6_gen_syndrome(disks, bytes, ptrs) |
| raid6_2data_recov() | raid6_recov_2data() |
| raid6_datap_recov() | raid6_recov_datap() |
| bvec_virt(&bio_iter_iovec(...)) | lvalue error in data/compress.c |

## 2. Building a DKMS source from upstream master

The upstream dkms.conf is generated from a template. Stage into /tmp first,
inspect, then copy into /usr/src. The version name differs from the packaged
bcachefs-1.36.1, so the two do not collide.

    cd ~/bcachefs-tools
    make dkms/dkms.conf
    make install_dkms DESTDIR=/tmp/dkms-stage
    ls /tmp/dkms-stage/usr/src/

Inspect the staged directory, then (system change):

    sudo cp -a /tmp/dkms-stage/usr/src/bcachefs-<version> /usr/src/
    sudo dkms add bcachefs/<version>
    sudo dkms build bcachefs/<version> -k <kernel>
    sudo dkms install bcachefs/<version> -k <kernel>

In the reported run, <version> was v1.39.6-2-g772d5cd02021 and <kernel> was
7.2.8_1.

## 3. Why a broken DKMS build produces a broken initramfs

On Void, the kernel install hooks run 10-dkms, then 20-initramfs. 10-dkms warns
and continues when a module build fails, so dracut ran with no bcachefs module
and produced an initramfs without bcachefs.ko. This is what happened in the
reported run (and in an earlier failure).

The 70bcachefs module in this repository now aborts the dracut run in that
situation. How the Void kernel-install hook behaves when dracut aborts, and
whether an existing /boot/initramfs-<version>.img survives, is not verified.

## 4. Build and verify the initramfs in /tmp first

    sudo dracut --force --kver <kernel> --add bcachefs --no-hostonly-cmdline \
      /tmp/test-initramfs.img
    sudo lsinitrd /tmp/test-initramfs.img | \
      grep -E 'kernel/fs/bcachefs|raid6_pq|xor\.ko'

In the report the dependencies present were raid6_pq, xor, lz4hc_compress,
libchacha and libpoly1305. Only copy the image to the boot location after this
check passes.

`--no-hostonly-cmdline` was used because hostonly mode stored root=UUID= as
the bcachefs sub-UUID, while booting uses the primary UUID. It also drops
`rd.driver.pre=bcachefs`; put root= and rd.driver.pre=bcachefs in the
bootloader options instead.

## 5. Putting it in the boot location

Principles from the report:

- Add new files under new names; do not overwrite existing ones (cp -n).
- Append a new bootloader entry; leave the old entry untouched, so you can
  boot back into it.
- Keep version_upgrade=none in the root mount options so the new module
  does not raise the on-disk format.
- Compare the copies with cmp after sync.

contrib/esp-deploy-sprout.sh implements this for a Sprout setup. It is
UNTESTED (syntax-checked only) and prints a TOML block for you to review and
append by hand.

## 6. After booting

    uname -r
    modinfo -n bcachefs
    modinfo bcachefs | grep -E '^(version|vermagic)'
    mount | grep ' / '

Check that `version_upgrade=none` is in the mount options. For the format
version, run `bcachefs show-super <device>` with a bcachefs-tools new enough
to know the format (see musl-userland.md); an older tool prints
"(unknown version)" for a newer format.

## 7. Next kernel update

1. Run the package update. In its output, look for the bcachefs DKMS module
   line ending in "done." If it says "FAILED!", stop: do not copy anything
   to the boot location and do not reboot.
2. If it failed, update the bcachefs source (section 2) and rebuild.
3. Build and verify the initramfs in /tmp (section 4).
4. Add the new files and a new bootloader entry (section 5).
5. Reboot, choose the new entry, run the checks in section 6.

Until the new entry boots, avoid xbps-reconfigure, `dkms remove`, and manual
dracut runs against /boot: hooks may regenerate initramfs files there and
change the state you are testing.

## 8. Checking the glibc side in a Bedrock stratum

Bedrock strata share the kernel and, in the verified setup, /lib/modules,
/boot and /tmp. A glibc Void stratum can therefore build an initramfs against
the same bcachefs module. This was checked for the initramfs build only; it
was not booted.

- Install dracut, bcachefs-tools and kmod inside the stratum, and copy
  module.d/70bcachefs into the stratum's /usr/lib/dracut/modules.d/.
- Because /boot is shared, write the output to /tmp only.
- Compare the libraries listed by `ldd /usr/bin/bcachefs` (run inside the
  stratum) with `lsinitrd` of the image.
- Expect Bedrock's /bedrock/cross stubs and firmware in the image; they
  appeared in the image that booted on musl as well.

## 9. Repairing a damaged ESP (manual only)

In the report, `fsck.fat -n` on the ESP found damage in two files that were not
used for booting (cross-linked clusters), plus stale FSInfo values. The
repair was done by hand in this order. Each step changes things, so run them
one at a time and look at the output before the next.

1. Back up the whole ESP image:

       sudo dd if=/dev/<esp-partition> of=<backup-image> bs=1M status=progress

   The backup contains the damage; restoring it restores the damage too.
2. Unmount: `sudo umount /boot/efi`
3. Repair (this rewrites the filesystem): `sudo fsck.fat -a /dev/<esp-partition>`
4. Remount and re-check: `sudo fsck.fat -n /dev/<esp-partition>`, then compare
   boot files with `cmp`.

This is deliberately not scripted.

## 10. Open items from the report

- "Volume was not properly unmounted" warnings on the ESP kept appearing;
  cause not determined (`sync` and `umount /boot/efi` before shutdown was the
  suggested way to isolate it).
- The 1.36.1 DKMS registered for 6.18.x kernels: whether it can mount a 1.39
  root was not checked.
- Booting with a newer bcachefs-tools inside the initramfs: not tested.
- The kernel was built without Rust support (CONFIG_RUST warning); no effect
  so far.
