# Building bcachefs-tools on Void musl

From the 2026-10-01 report. The build hit a chain of separate failures; each
was handled outside the source tree (environment, packages) except one,
which needed a patch. These failures were seen on a musl host; they were not
checked on glibc, where the build may need none of this.

Source: bcachefs-tools master at v1.39.6-2-g772d5cd02.

| # | Symptom | Cause | Workaround |
|---|---|---|---|
| 1 | pkg-config cannot find blkid, uuid, liburcu, etc. | missing -devel packages | install them (below) |
| 2 | cargo fails to run sccache | rustc wrapper configured, sccache absent | `RUSTC_WRAPPER=` (empty) |
| 3 | bindgen: cannot open libclang ("Dynamic loading not supported") | musl host Rust links build scripts statically, so dlopen fails | `RUSTFLAGS="-C target-feature=-crt-static"` |
| 4 | `libc::statx` not found (src/util.rs) | not available for the musl target in the libc crate used; the exact cfg condition was not traced | patch `path_subvol()` to use `rustix::fs::statx` |

Packages named in the report for step 1: libblkid-devel, libuuid-devel,
libsodium-devel, liblz4-devel, eudev-libudev-devel, keyutils-devel,
libunwind-devel, libaio-devel, liburcu-devel, rust-bindgen. The report counts
11 packages but names these 10; the eleventh was not recorded. Preview with
`xbps-install -n <pkg>`, and use pkg-config's error messages to find anything
still missing.

The patch is in `patches/bcachefs-tools-772d5cd02-musl-statx.patch`
(4 lines added, 10 removed in src/util.rs). It was checked to match the tree
that built; it may not apply to other commits.

Build:

    cd ~/bcachefs-tools
    git apply /path/to/dracut-bcachefs/patches/bcachefs-tools-772d5cd02-musl-statx.patch
    RUSTC_WRAPPER= RUSTFLAGS="-C target-feature=-crt-static" make -j$(nproc)
    ./bcachefs version

Result in the report: a dynamically linked musl executable whose `show-super`
printed `per_dev_fragmentation_lru (1.39)`. The packaged 1.36.1 tool printed
"(unknown version)" for the same filesystem, which only means the tool did
not know format 1.39.

The report kept the new binary under ~/.local/bin instead of replacing
/usr/bin/bcachefs, because that file is managed by xbps, and dracut would
pull a replacement into the next initramfs, mixing an untested userland
into the boot path.
