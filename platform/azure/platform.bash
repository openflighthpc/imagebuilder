yum -y install WALinuxAgent

yum -y install cloud-init cloud-utils-growpart

cat << EOF > /etc/waagent.conf
#
# Microsoft Azure Linux Agent Configuration
#
Provisioning.Enabled=n
Provisioning.UseCloudInit=y
Provisioning.DeleteRootPassword=n
Provisioning.RegenerateSshHostKeyPair=y
Provisioning.SshHostKeyPairType=rsa
Provisioning.MonitorHostName=y
Provisioning.DecodeCustomData=n
Provisioning.ExecuteCustomData=n
Provisioning.AllowResetSysUser=n
ResourceDisk.Format=y
ResourceDisk.Filesystem=ext4
ResourceDisk.MountPoint=/mnt/resource
ResourceDisk.EnableSwap=y
ResourceDisk.SwapSizeMB=16384
ResourceDisk.MountOptions=None
Logs.Verbose=n
OS.RootDeviceScsiTimeout=300
OS.OpensslPath=None
OS.SshDir=/etc/ssh
OS.EnableFirewall=n
EOF

systemctl enable waagent

# Configure cloud-init
cat > /etc/cloud/cloud.cfg << END
users:
 - default

disable_root: 1
ssh_pwauth:   0

mount_default_fields: [~, ~, 'auto', 'defaults,nofail,x-systemd.requires=cloud-init.service', '0', '2']
resize_rootfs_tmp: /dev
ssh_svcname: sshd
ssh_deletekeys:   True
ssh_genkeytypes:  [ 'rsa', 'ecdsa', 'ed25519' ]
syslog_fix_perms: ~

cloud_init_modules:
 - disk_setup
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
 - power-state-change

system_info:
  default_user:
    name: centos
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

#mounts:
# - [ ephemeral0, /media/ephemeral0 ]
# - [ ephemeral1, /media/ephemeral1 ]
# - [ swap, none, swap, sw, "0", "0" ]

# vim:syntax=yaml
END

systemctl enable cloud-init.service

echo 'azure' > /etc/yum/vars/infra

