yum -y install cloud-init cloud-utils-growpart

# Configure cloud-init
cat > /etc/cloud/cloud.cfg << END
users:
 - default

disable_root: 1
ssh_pwauth:   0

mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']
resize_rootfs_tmp: /dev
ssh_svcname: sshd
ssh_deletekeys:   True
ssh_genkeytypes:  [ 'rsa', 'ecdsa', 'ed25519' ]
syslog_fix_perms: ~

cloud_init_modules:
 - migrator
 - bootcmd
 - write-files
 - growpart
 - resizefs
 - set_hostname
 - update_hostname
 - update_etc_hosts
 - rsyslog
 - users-groups
 - ssh

cloud_config_modules:
 - mounts
 - locale
 - set-passwords
 - yum-add-repo
 - package-update-upgrade-install
 - timezone
 - puppet
 - chef
 - salt-minion
 - mcollective
 - disable-ec2-metadata
 - runcmd

cloud_final_modules:
 - rightscale_userdata
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - ssh-authkey-fingerprints
 - keys-to-console
 - phone-home
 - final-message

system_info:
  default_user:
    name: openflight
    lock_passwd: true
    gecos: Cloud User
    groups: [wheel, adm, systemd-journal]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  distro: rhel
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd

mounts:
 - [ ephemeral0, /media/ephemeral0 ]
 - [ ephemeral1, /media/ephemeral1 ]
 - [ swap, none, swap, sw, "0", "0" ]

datasource_list: [ OpenStack, NoCloud, None ]

# vim:syntax=yaml
END

systemctl enable cloud-init.service

echo 'stock' > /etc/yum/vars/infra

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
