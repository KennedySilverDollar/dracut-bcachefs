#!/bin/sh
# 70bcachefs/bcachefs_timeout.sh
#
# Runs when initqueue times out waiting for the root device.
# Gives udev one more chance to settle before initqueue gives up.
#
# Unlike 70btrfs/btrfs_timeout.sh, which rescans devices with
# "btrfs device scan", this hook only waits for udev to settle.
udevadm settle --timeout=30
