
# Install necessary packages
if [ ${DISTROMAJOR} -eq 8 ] || [ ${DISTROMAJOR} -eq 9 ]; then
  dnf -y install openssh-server grub2 acpid gdisk kernel
  dnf -y install tuned dhcp-client
else
  yum -y install openssh-server grub2 acpid deltarpm gdisk
fi

#yum update
if [ ${DISTROMAJOR} -eq 8 ] || [ ${DISTROMAJOR} -eq 9 ]; then
  dnf -y update
else
  yum -y update
fi

#if [ ${DISTROMAJOR} -eq 7 ]; then
#  cat << EOF > /etc/NetworkManager/conf.d/99-disableNMDNS.conf
#[main]
#dns=none
#EOF
#fi

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
ZONE=external
END

rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

#LOCALE
ln -snf /usr/share/zoneinfo/UTC /etc/localtime
echo 'ZONE="UTC"' > /etc/sysconfig/clock

if [ ${BOOTABLE} -gt 0 ]; then
  if [ ${EFI} -gt 0 ]; then
    # fstab
    cat > /etc/fstab << END
LABEL=root /         xfs    defaults,relatime  1 1
LABEL=boot /boot     xfs    defaults,relatime  1 1
LABEL=efi /boot/efi  vfat   defaults,uid=0,gid=0,umask=0077,shortname=winnt 0 0
tmpfs   /dev/shm  tmpfs   defaults           0 0
devpts  /dev/pts  devpts  gid=5,mode=620     0 0
sysfs   /sys      sysfs   defaults           0 0
proc    /proc     proc    defaults           0 0
END
  else
    # fstab
    cat > /etc/fstab << END
LABEL=root /         xfs    defaults,relatime  1 1
tmpfs   /dev/shm  tmpfs   defaults           0 0
devpts  /dev/pts  devpts  gid=5,mode=620     0 0
sysfs   /sys      sysfs   defaults           0 0
proc    /proc     proc    defaults           0 0
END
  fi

if [ ${DISTROMAJOR} -eq 9 ]; then
  #grub config taken from /etc/sysconfig/grub on RHEL7 AMI
  cat > /etc/default/grub << END
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_TIMEOUT=1
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto console=ttyS0,115200n8 console=tty0 net.ifnames=0 blacklist=nouveau rdblacklist=nouveau nouveau.modeset=0"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=false
END
else
  #grub config taken from /etc/sysconfig/grub on RHEL7 AMI
  cat > /etc/default/grub << END
GRUB_TIMEOUT=1
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto console=ttyS0,115200n8 console=tty0 net.ifnames=0 blacklist=nouveau rdblacklist=nouveau nouveau.modeset=0"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=false
END
fi

  if [ ${EFI} -gt 0 ]; then
    #specific kernel cmdline for azure :|
    sed -i -e 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="rootdelay=300 console=ttyS0 earlyprintk=ttyS0 crashkernel=auto console=ttyS0,115200n8 net.ifnames=0 blacklist=nouveau rdblacklist=nouveau nouveau.modeset=0"/g' /etc/default/grub
    yum -y install grub2-efi shim efibootmgr grub2-efi-x64
    export GRUB_ENABLE_BLSCFG=false
    grub2-mkconfig -o /etc/grub2.cfg
    grub2-mkconfig -o /etc/grub2-efi.cfg
    grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg
    sed --follow-symlinks -i -e 's/linux16/linuxefi/g' -e 's/initrd16/initrdefi/g' /etc/grub2-efi.cfg
    
  fi
  # Install grub2
  export GRUB_ENABLE_BLSCFG=false
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

ln -snf /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules

mkdir -p /var/lib/firstrun/{bin,scripts}
mkdir -p /var/log/firstrun/

#Install firstrun

cat << EOF > /var/lib/firstrun/bin/firstrun
#!/bin/bash
function fr {
  echo "-------------------------------------------------------------------------------"
  echo "Symphony deployment Suite - Copyright (c) 2008-2017 Alces Software Ltd"
  echo "-------------------------------------------------------------------------------"
  echo "Running Firstrun scripts.."
  if [ -f /var/lib/firstrun/RUN ]; then
    for script in \`find /var/lib/firstrun/scripts -type f -iname *.bash\`; do
      echo "Running \$script.." >> /root/firstrun.log 2>&1
      /bin/bash \$script >> /root/firstrun.log 2>&1
    done
    rm -f /var/lib/firstrun/RUN
  fi
  echo "Done!"
  echo "-------------------------------------------------------------------------------"
}
trap fr EXIT
EOF

cat << EOF > /var/lib/firstrun/bin/firstrun-stop
#!/bin/bash
/bin/systemctl disable firstrun.service
if [ -f /firstrun.reboot ]; then
  echo -n "Reboot flag set.. Rebooting.."
  rm -f /firstrun.rebooot
  shutdown -r now
fi
EOF

cat << EOF >> /etc/systemd/system/firstrun.service
[Unit]
Description=FirstRun service
After=network-online.target remote-fs.target
Before=display-manager.service getty@tty1.service
[Service]
ExecStart=/bin/bash /var/lib/firstrun/bin/firstrun
Type=oneshot
ExecStartPost=/bin/bash /var/lib/firstrun/bin/firstrun-stop
SysVStartPriority=99
TimeoutSec=0
RemainAfterExit=yes
Environment=HOME=/root
Environment=USER=root
[Install]
WantedBy=multi-user.target
EOF

chmod 664 /etc/systemd/system/firstrun.service
systemctl enable firstrun.service
touch /var/lib/firstrun/RUN
