#!/bin/bash
echo "Attempting Cleanup.."

rm -rf ${ROOTFS}/tmp/*

umount ${ROOTFS}/dev
umount ${ROOTFS}/proc
umount ${ROOTFS}/sys/fs/fuse/connections/
umount ${ROOTFS}/sys

sync
sleep 5
umount ${ROOTFS}

losetup -d $DEVICE

echo "If there are errors above, you may need to cleanup for me"
