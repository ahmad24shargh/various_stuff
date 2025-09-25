#!/usr/bin/env bash
if [ $(id -u) -ne '0' ];then
	echo "Error: This script must be run with root user permissions."
	exit 1
fi

unset LD_PRELOAD

# The path of Ubuntu/debian rootfs
UBUNTUPATH="/data/local/chroot-distro/installed-rootfs/debian"

# Fix setuid issue
/data/adb/lpu/bin/busybox mount -o remount,dev,suid /data

/data/adb/lpu/bin/busybox mount --bind /dev $UBUNTUPATH/dev
/data/adb/lpu/bin/busybox mount --bind /sys $UBUNTUPATH/sys
/data/adb/lpu/bin/busybox mount --bind /proc $UBUNTUPATH/proc
/data/adb/lpu/bin/busybox mount -t devpts devpts $UBUNTUPATH/dev/pts

# /dev/shm for Electron apps
mkdir -p /dev/shm $UBUNTUPATH/dev/shm
/data/adb/lpu/bin/busybox mount -t tmpfs -o size=256M tmpfs $UBUNTUPATH/dev/shm
#OLD_PATH="$PATH"
#export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games:/system/bin:/system/xbin"

# Mount sdcard
mkdir -p $UBUNTUPATH/sdcard
/data/adb/lpu/bin/busybox mount --bind /sdcard $UBUNTUPATH/sdcard

# Mount Termux-home dir
mkdir -p $UBUNTUPATH/termux
/data/adb/lpu/bin/busybox mount --bind /data/data/com.termux/files/home $UBUNTUPATH/termux

# chroot into Ubuntu/debian
/data/adb/lpu/bin/busybox chroot $UBUNTUPATH /bin/su - root

/data/adb/lpu/bin/busybox umount $UBUNTUPATH/termux
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/sdcard
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/dev/shm
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/dev/pts
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/proc
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/sys
/data/adb/lpu/bin/busybox umount $UBUNTUPATH/dev
#export PATH="$OLD_PATH"
