systemctl disable cloud-init.service

echo 'stock' > /etc/yum/vars/infra

passwd -u root
echo "root:sqrt(s*w)" | chpasswd

cat <<EOF > /etc/dracut.conf.d/10-ahci.conf
add_drivers+=" ahci "
EOF

# Recreate initramfs
KVER=$(echo /boot/vmlinuz-3* | cut -f2- -d'-')
dracut -f /boot/initramfs-${KVER}.img ${KVER}
