
# Install necessary packages
yum -y install openssh-server grub2 acpid deltarpm gdisk

# Remove unnecessary packages
UNNECESSARY="linux-firmware ivtv-firmware iwl*firmware"
yum -C -y remove $UNNECESSARY --setopt="clean_requirements_on_remove=1"

## Networking setup
cat > /etc/hosts << END
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
END
cat > /etc/sysconfig/network << END
NETWORKING=yes
NOZEROCONF=yes
END
cat > /etc/sysconfig/network-scripts/ifcfg-eth0  << END
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
PERSISTENT_DHCLIENT=1
END

rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

#LOCALE
ln -snf /usr/share/zoneinfo/UTC /etc/localtime
echo 'ZONE="UTC"' > /etc/sysconfig/clock

if [ ${BOOTABLE} -gt 0 ]; then
  # fstab
  cat > /etc/fstab << END
LABEL=root /         xfs    defaults,relatime  1 1
tmpfs   /dev/shm  tmpfs   defaults           0 0
devpts  /dev/pts  devpts  gid=5,mode=620     0 0
sysfs   /sys      sysfs   defaults           0 0
proc    /proc     proc    defaults           0 0
END
  #grub config taken from /etc/sysconfig/grub on RHEL7 AMI
  cat > /etc/default/grub << END
GRUB_TIMEOUT=1
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto console=ttyS0,115200n8 console=tty0 net.ifnames=0 blacklist=nouveau rdblacklist=nouveau nouveau.modeset=0"
GRUB_DISABLE_RECOVERY="true"
END

  # Recreate initramfs
  KVER=$(echo /boot/vmlinuz-3* | cut -f2- -d'-')
  dracut -f /boot/initramfs-${KVER}.img ${KVER}

  # Install grub2
  grub2-mkconfig -o /boot/grub2/grub.cfg
  grub2-install $DEVICE

else
  # fstab
  cat > /etc/fstab << END
LABEL=root /         ext4    defaults,relatime  1 1
tmpfs   /dev/shm  tmpfs   defaults           0 0
devpts  /dev/pts  devpts  gid=5,mode=620     0 0
sysfs   /sys      sysfs   defaults           0 0
proc    /proc     proc    defaults           0 0
END
fi

echo 'RUN_FIRSTBOOT=NO' > /etc/sysconfig/firstboot
# Startup services
systemctl enable sshd.service
systemctl mask tmp.mount

#Prevent nouveau load
echo "blacklist nouveau" > /etc/modprobe.d/nouveau.conf

#Disable SELinux
sed -i -e 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config

sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

echo "virtual-guest" > /etc/tuned/active_profile

cat  >> /etc/dhcp/dhclient.conf << EOF

timeout 300;
retry 60;
EOF

cat <<EOL > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel
EOL

sed -e "s/Defaults    requiretty/#Defaults    requiretty/g" -i /etc/sudoers

dd if=/dev/urandom count=50|md5sum|passwd --stdin root
passwd -l root

#Change default runlevel
ln -snf /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target

