#!/bin/bash 

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
IMAGESIZE=10 #size in GB
if [ ${DISTROMAJOR} -eq 8 ]; then
  YUMCONF=${MYDIR}/../yum/dnf.conf
elif  [ ${DISTROMAJOR} -eq 9 ]; then
  YUMCONF=${MYDIR}/../yum/dnf9.conf
else
  YUMCONF=${MYDIR}/../yum/yum.conf
fi
SCRIPTS=${MYDIR}/../scripts/

if [ -f "${IMAGE}" ] ; then
  echo "Image exists.." >&2
  exit 1
fi

echo "Prepping image - Logging to /tmp/imageprep.log.." 
{ 
  dd if=/dev/zero of=${IMAGE} bs=1 count=0 seek=${IMAGESIZE}G
  losetup $DEVICE $IMAGE
  sleep 1
} >/tmp/imageprep.log 2>&1

if ! [ -b $DEVICE ]; then
  echo "Problem with image.." >&2
  exit 1
fi

echo "Partition & Format - Logging to /tmp/partitionformat.log.. "
{
  mkdir -p $ROOTFS
  if [ ${BOOTABLE} -gt 0 ]; then 
    echo "Bootable image creating.."
    if [ ${EFI} -gt 0 ]; then
      cat << END | parted ${DEVICE}
mktable gpt
mkpart primary ext2 1 2
set 1 bios_grub on
mkpart 'EFI System Partition' fat16 2 200M
set 2 boot on
mkpart primary xfs 200M 500M
mkpart primary xfs 500M 100%
quit
END
    else
      cat << END | parted ${DEVICE}
mktable gpt
mkpart primary ext2 1 2
set 1 bios_grub on
mkpart primary xfs 2 100%
quit
END
    fi
    # Wait for a moment, because partition might not have been picked up yet.
    echo "Parted complete - syncing"
    sleep 5
    if [ ${EFI} -gt 0 ]; then
      mkfs.fat -n efi -F16 ${DEVICE}p2
      mkfs.xfs -f -n ftype=1 -L boot ${DEVICE}p3
      mkfs.xfs -f -n ftype=1 -L root ${DEVICE}p4
      mount ${DEVICE}p4 $ROOTFS
      mkdir -p $ROOTFS/boot/
      mount ${DEVICE}p3 $ROOTFS/boot
      mkdir -p $ROOTFS/boot/efi
      mount ${DEVICE}p2 $ROOTFS/boot/efi
    else
      mkfs.xfs -f -n ftype=1 -L root ${DEVICE}p2
      mount ${DEVICE}p2 $ROOTFS
    fi
  else
    echo "Plain image creating.."
    mkfs.ext4 -L root -F ${DEVICE}
    mount ${DEVICE} ${ROOTFS}
  fi 
} >/tmp/partitionformat.log 2>&1

### Basic OS Install
echo "Installing OS - logging to /tmp/osinstall.log.."

if [ $DISTROMAJOR -eq 7 ]; then
  yum clean all > /tmp/osinstall.log 2>&1
  yum groups -c $YUMCONF -y install "Compute Node" "Core" --releasever=${DISTROMAJOR} --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
  yum -c $YUMCONF -y install vim emacs xauth xhost xdpyinfo xterm xclock tigervnc-server ntpdate vconfig bridge-utils patch tcl-devel gettext wget dracut-network nfs-utils --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
elif [ $DISTROMAJOR -eq 8 ] ; then
  dnf clean all > /tmp/osinstall.log 2>&1
  dnf groups -c $YUMCONF -y install "Minimal Install" "Core" --releasever=${DISTROMAJOR} --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
  dnf -c $YUMCONF -y install vim emacs xauth xhost xdpyinfo xterm tigervnc-server patch tcl-devel gettext wget dracut-network nfs-utils --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
  dnf clean all
  rpmdb --rebuilddb
elif [ $DISTROMAJOR -eq 9 ]; then
  dnf groups -c $YUMCONF -y install "Minimal Install" "Core" --releasever=${DISTROMAJOR} --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
  dnf -c $YUMCONF -y install vim emacs xauth xhost xdpyinfo xterm tigervnc-server patch tcl-devel gettext wget dracut-network nfs-utils --installroot=$ROOTFS >> /tmp/osinstall.log 2>&1
  dnf clean all
  rpmdb --rebuilddb
fi

echo "Prepping chroot.."

mount --bind /dev ${ROOTFS}/dev
mount --bind /sys ${ROOTFS}/sys
mount -t proc none ${ROOTFS}/proc

cp -v /etc/resolv.conf ${ROOTFS}/etc/resolv.conf

cp -pav ${SCRIPTS}/*.bash ${ROOTFS}/tmp/.
echo "Base - Logging to /tmp/imagebase.log.."
{
  chroot ${ROOTFS} bash -ex /tmp/base.bash
} >/tmp/imagebase.log 2>&1 || {
  echo "Failed to run base script" >&2
}
echo "Image Cleanup - Logging to /tmp/imagecleanup.log"
{
  chroot ${ROOTFS} bash -ex /tmp/cleanup.bash
} >/tmp/imagecleanup.log 2>&1 || {
  echo "Failed to run cleanup script" >&2
}


bash ${MYDIR}/cleanup.bash
