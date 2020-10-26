echo 'stock' > /etc/yum/vars/infra

passwd -u root
echo "root:sqrt(s*w)" | chpasswd

cat <<EOF > /etc/dracut.conf.d/11-ahci.conf
add_drivers+=" ahci "
EOF

if [ ${DISTROMAJOR} -eq 8 ]; then
  cat <<EOF > /etc/dracut.conf.d/11-virtio.conf
add_drivers+=" virtio_console virtio_blk virtio_net virtio_scsi "
EOF
else
  cat <<EOF > /etc/dracut.conf.d/11-virtio.conf
add_drivers+=" virtio virtio_pci virtio_blk virtio_net virtio_scsi virtio_ring "
EOF
fi


# Recreate initramfs
KVER=$(echo /boot/vmlinuz-*.x86_64 | cut -f2- -d'-')
dracut -f /boot/initramfs-${KVER}.img ${KVER}

echo "Listing initrd for reference" 
lsinitrd /boot/initramfs-${KVER}.img
