#!/bin/sh
# 70bcachefs/bcachefs_timeout.sh
#
# Runs when initqueue times out waiting for the root device.
# Mirrors dracut's 70btrfs/btrfs_timeout.sh: give udev one more
# chance to settle before giving up.
udevadm settle --timeout=30