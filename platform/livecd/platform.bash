echo 'stock' > /etc/yum/vars/infra

passwd -u root
echo "root:sqrt(s*w)" | chpasswd

echo "Hacking fstab..:"
cat << EOF > /etc/fstab
/dev/root  /         xfs    defaults,noatime 0 0
tmpfs   /dev/shm    tmpfs   defaults   0 0
sysfs   /sys        sysfs   defaults   0 0
proc    /proc       proc    defaults   0 0
EOF

cat <<EOF > /etc/dracut.conf.d/11-ahci.conf
add_drivers+=" ahci "
EOF

echo "Setting readonly root.."
sed -e 's/^TEMPORARY_STATE=.*$/TEMPORARY_STATE=yes/g' -i /etc/sysconfig/readonly-root
sed -e 's/^READONLY=.*$/READONLY=yes/g' -i /etc/sysconfig/readonly-root
cat <<EOF > /etc/rwtab
dirs	/var/cache/man
dirs	/var/gdm
dirs	/var/lib/xkb
dirs	/var/log
dirs	/var/lib/puppet
dirs	/var/lib/dbus

empty	/tmp
empty	/var/cache/foomatic
empty	/var/cache/logwatch
empty	/var/cache/httpd/ssl
empty	/var/cache/httpd/proxy
empty	/var/cache/php-pear
empty	/var/cache/systemtap
empty	/var/db/nscd
empty	/var/lib/dav
empty	/var/lib/dhcpd
empty	/var/lib/dhclient
empty	/var/lib/php
empty	/var/lib/pulse
empty	/var/lib/systemd/timers
empty	/var/lib/ups
empty	/var/tmp

files	/etc/adjtime
files	/etc/ntp.conf
files	/etc/resolv.conf
files	/etc/lvm/cache
files	/etc/lvm/archive
files	/etc/lvm/backup
files	/var/account
files	/var/lib/arpwatch
files	/var/lib/NetworkManager
files	/var/cache/alchemist
files	/var/lib/gdm
files	/var/lib/iscsi
files	/var/lib/logrotate.status
files	/var/lib/ntp
files	/var/lib/xen
files	/var/empty/sshd/etc/localtime
files	/var/lib/systemd/random-seed
files	/var/spool
files	/var/lib/samba
files   /var/log/audit/audit.log
files	/var/lib/nfs
EOF


# Recreate initramfs
KVER=$(echo /boot/vmlinuz-3* | cut -f2- -d'-')
dracut -N -a livenet -a dmsquash-live -a nfs -a biosdevname -f -v /boot/initramfs-${KVER}.img ${KVER}

echo "Listing initrd for reference" 
lsinitrd /boot/initramfs-${KVER}.img
