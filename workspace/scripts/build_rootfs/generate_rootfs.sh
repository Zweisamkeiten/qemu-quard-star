#!/bin/bash
losetup -o 0 --sizelimit 1073741824 /dev/loop70 "$1" -P
echo -e "I\n$1\nw\n" | fdisk /dev/loop70
losetup -d /dev/loop70
sync
losetup -o 0 --sizelimit 1073741824 /dev/loop70 "$1" -P
mkfs.vfat /dev/loop70p1
mkfs.ext4 /dev/loop70p2
losetup -d /dev/loop70
sync