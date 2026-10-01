#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# UNTESTED: syntax-checked only, never run end to end.
# Sprout-specific (TOML output). Needs ROOT_UUID; see usage below.
# 使い方: sudo ROOT_UUID=<uuid> ./esp-deploy-sprout.sh <kernel-version>   例: sudo ROOT_UUID=<uuid> ./esp-deploy-sprout.sh 7.2.8_1
# 非破壊: 既存ファイルは上書きせず、sprout.toml と efibootmgr には触れない。
set -eu
VER="${1:?kernel version required}"
ROOT_UUID="${ROOT_UUID:?set ROOT_UUID to the primary UUID of the bcachefs root}"
ROOTFLAGS="${ROOTFLAGS:-version_upgrade=none}"
ESP=/boot/efi
OUT=/tmp/initramfs-${VER}-bcachefs.img

findmnt -n -o FSTYPE "$ESP" | grep -q vfat || { echo "ESP not mounted"; exit 1; }
[ -f "/boot/vmlinuz-$VER" ] || { echo "no /boot/vmlinuz-$VER"; exit 1; }
find "/lib/modules/$VER" -name 'bcachefs.ko*' | grep -q . \
  || { echo "bcachefs module missing for $VER (run dkms build/install first)"; exit 1; }
for f in "$ESP/vmlinuz-$VER" "$ESP/initramfs-$VER-bcachefs.img"; do
  [ ! -e "$f" ] || { echo "already exists: $f"; exit 1; }
done

dracut --force --kver "$VER" --add bcachefs --no-hostonly-cmdline "$OUT"
lsinitrd "$OUT" | grep -q 'kernel/fs/bcachefs/bcachefs.ko' \
  || { echo "bcachefs.ko NOT in initramfs: abort"; exit 1; }
lsinitrd "$OUT" | grep -q 'raid6_pq' || { echo "raid6_pq missing: abort"; exit 1; }

NEED=$(( ($(stat -c %s "$OUT") + $(stat -c %s "/boot/vmlinuz-$VER")) / 1024 ))
AVAIL=$(df --output=avail -k "$ESP" | tail -1)
[ "$AVAIL" -gt $((NEED + 51200)) ] || { echo "ESP space low"; exit 1; }

cp -n "/boot/vmlinuz-$VER" "$ESP/vmlinuz-$VER"
cp -n "$OUT" "$ESP/initramfs-$VER-bcachefs.img"
sync
cmp "/boot/vmlinuz-$VER" "$ESP/vmlinuz-$VER"
cmp "$OUT" "$ESP/initramfs-$VER-bcachefs.img"
echo "OK: copied and verified."
echo
echo "--- sprout.toml に追記する内容(手動で確認して追記) ---"
V=${VER//[_.]/-}
cat << TOML

[entries.void-linux-$V]
title = "Void Linux $VER (bcachefs test)"
actions = ["boot-linux-$V"]

[actions.boot-linux-$V]
chainload.path = "\\\\vmlinuz-$VER"
chainload.linux-initrd = "\\\\initramfs-$VER-bcachefs.img"
chainload.options = [
    "root=UUID=${ROOT_UUID}",
    "rootfstype=bcachefs",
    "rootflags=${ROOTFLAGS}",
    "rd.driver.pre=bcachefs",
    "rw",
    "loglevel=7"
]
TOML
