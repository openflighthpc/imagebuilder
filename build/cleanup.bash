#!/bin/bash
echo "Attempting Cleanup.."

rm -rf ${ROOTFS}/var/tmp/*
rm -rf ${ROOTFS}/tmp/*

umount ${ROOTFS}/dev
umount ${ROOTFS}/proc
umount ${ROOTFS}/sys/fs/fuse/connections/
umount ${ROOTFS}/sys

sync
sleep 5
umount ${ROOTFS}/boot/efi || true 
umount ${ROOTFS}/boot/ || true 
umount ${ROOTFS}

losetup -d $DEVICE

echo "If there are errors above, you may need to cleanup for me"
