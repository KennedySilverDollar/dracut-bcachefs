#!/bin/bash
# 70bcachefs/module-setup.sh
#
# dracut integration module for bcachefs.
#
# Void Linux's bcachefs-tools package ships an initramfs-tools hook
# (/usr/share/initramfs-tools/hooks/bcachefs) but no dracut module.
# This module fills that gap. Structure mirrors dracut's own 70btrfs
# and 70dm modules

# called by dracut
check() {
  # bcachefs binary must exist on the build host, otherwise there
  # is noting for this module to include.
  require_binaries bcachefs || return 1

  # In hostonly mode (or when mount_needs is explicitly),
  # only include this module if bcachefs is actually in use on the host
  # Otherwise skip (255) to avoid bloating hostonly images on
  # machines that don't use bcachefs at all.
  [[ $hostonly ]] || [[ $mount_needs ]] && {
    for fs in "${host_fs_types[@]}"; do
      [[ $fs == "bcachefs" ]] && return 0
      done
      return 255
  }

  # Generic (portable) build: always include.
  return 0
}

# called by dracut
depends(){
  # udev-rules: needed for 64-bcachefs. rules(device-ready detaction)
  # initqueue : the root mount attempt happens inside this module's
  # loop
  echo udev-rules initqueue
  return 0
}

# called by dracut2
cmdline(){
  # Same rationale as dracut's own btrfs module
  # (see dracutdevs/dracut#658): on slower machines, initqueue may
  # try to mount root before the filesystem module has finished
  # loading. bcachefs.ko is larger than btrfs.ko and therefore more
  # prone to this race, so the same guard is applied pre-emptively.
  printf "rd.driver.pre=bcachefs"
}

# called by dracut3
installkernel(){
  hostonly='' instmods bcachefs
}

# called by dracut4
install(){
  # udev rule shipped directly by bcachefs-tools; no fallback file
  # needed (unlike btrfs, which ships a bundled fallback rule for
  # distros that don't provide one).
  inst_rules 64-bcachefs.rules

  # Timeout hook for non-systemd initramfs builds, mirroring
  # 70btrfs/btrfs_timeout.sh
  if ! dracut_module_included "systemd"; then
    inst_hook initqueue/timeout 10 "$moddir/bcachefs_timeout.sh"
  fi

  # bcachefs-tools unifies mount/fsck/recovery into a single binary
  # with symlinks. Install the binary plus the fsck.* and mount.*
  # symlinks explicitly, since some dracut/initqueue internals
  # invoke filesystem tools by the fsck.<fstype> / mount.<fstype>
  # convention rather than relying on PATH resolution alone.
  inst_multiple -o fsck.bcachefs mount.bcachefs
  inst bcachefs /sbin/bcachefs

  # Only emit the cmdline() output as a conf file when building a
  # generic image with hostonly_cmdline enabled (same pattern as 70 btrfs).
  if [[ $hostonly_cmdline == "yes" ]]; then
    printf "%s\n" "$(cmdline)" > "${initdir}/etc/cmdline.d/20-bcachefs.conf"
  fi
}

