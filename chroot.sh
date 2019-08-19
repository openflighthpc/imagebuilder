#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export DEVICE=`losetup -f`
ROOTFS=/mnt/sysimage
IMAGE=/tmp/VHD.img

if ! [ -f "${IMAGE}" ] ; then
  echo "Image doesnt exist.." >&2
  exit 1
fi


if ! [ -d "${ROOTFS}" ]; then
  mkdir ${ROOTFS}
fi

losetup $DEVICE $IMAGE

sleep 2
mount ${DEVICE}p2 $ROOTFS
sleep 1
mount -o bind /proc ${ROOTFS}/proc
mount -o bind /dev ${ROOTFS}/dev
mount -o bind /sys ${ROOTFS}/sys

cp -pav /etc/resolv.conf ${ROOTFS}/etc/resolv.conf
echo "Entering CHROOT.."
chroot ${ROOTFS}
echo "Exiting CHROOT.."
umount ${ROOTFS}/dev
umount ${ROOTFS}/sys
umount ${ROOTFS}/proc

umount ${ROOTFS}

losetup -d $DEVICE
