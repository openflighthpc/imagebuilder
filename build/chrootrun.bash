#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

INSCRIPT=$1
LOG=$2
ERROR=0

if [ -z "${INSCRIPT}" ] || (! [ "${INSCRIPT}" == 'bash' ] && ! [ -f "${INSCRIPT}" ]); then
  echo "Full path to script plz or 'bash'.." >&2
  exit 1
fi

if [ -z "${LOG}" ]; then
  LOG="/tmp/chrootrun.log"
fi

INSCRIPTNAME=`basename ${INSCRIPT}`

if [ -z "${DEVICE}" ]; then
  export DEVICE=`losetup -f`
fi
if [ -z "${ROOTFS}" ]; then
  export ROOTFS=/mnt/sysimage
fi
if [ -z "${IMAGE}" ]; then
  export IMAGE=/tmp/VHD.img
fi

if ! [ -f "${IMAGE}" ] ; then
  echo "Image doesnt exist.." >&2
  exit 1
fi

if ! [ -d "${ROOTFS}" ]; then
  mkdir ${ROOTFS}
fi

losetup $DEVICE $IMAGE

sleep 2

if [ "${BOOTABLE}" -gt 0 ]; then
  mount ${DEVICE}p2 ${ROOTFS}
else
  mount ${DEVICE} ${ROOTFS}
fi

sleep 1
mount -o bind /proc ${ROOTFS}/proc
mount -o bind /dev ${ROOTFS}/dev
mount -o bind /sys ${ROOTFS}/sys
mount -o bind / ${ROOTFS}/mnt/

cp -pav /etc/resolv.conf ${ROOTFS}/etc/resolv.conf

if [ "${INSCRIPT}" == 'bash' ]; then
  INSCRIPT=""
else
  cp -pav ${INSCRIPT} ${ROOTFS}/tmp/${INSCRIPTNAME}
fi

if  [ -z "${INSCRIPT}" ]; then
  {
    echo "Entering CHROOT - use 'exit' to finish"
    chroot ${ROOTFS} /bin/bash
  }
else
  echo "Entering CHROOT to run ${INSCRIPT} - Logging to $LOG"
  { 
    chroot ${ROOTFS} bash -e /tmp/${INSCRIPTNAME}
  } > $LOG 2>&1 || {
    echo "Failed to run your script cleanly" >&2
    export ERROR=1
  }
fi
echo "Exiting CHROOT.."
umount ${ROOTFS}/mnt
umount ${ROOTFS}/dev
umount ${ROOTFS}/sys
umount ${ROOTFS}/proc

umount ${ROOTFS}

losetup -d $DEVICE

if [ ${ERROR} -eq 1 ]; then
  exit 1
fi
