#!/bin/bash

echo "Generating example config iso"

if [ -f /tmp/imageiso ]; then
  rm -rf /tmp/imageiso
fi
mkdir -p /tmp/imageiso/

META=/tmp/imageiso/meta-data
USER=/tmp/imageiso/user-data
ISO=/tmp/imageiso/config.iso

cat << EOF > $META
instance-id: iid-local01
dsmode: local
local-hostname: metalcontroller
hostname: metalcontroller
fqdn: metalcontroller.privatecluster.alces.network
public-keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEYF+FaLcN52wFAcbDPZSsws+RIs61CsPSbqXHSU4j41/pJaHtaPoegLyreA5kO9SuqTEc275AKEdkd8XZP1rp3MxA7hHYsShMyvRBPlWtwT+hOIFrYzZ9kLyRpo6qx8StSj66AUVfw3DnKfDk97Ory4SyafA8BVoReqSUizogkr+bgsQro1fiyDQM+L/o++zPewnGoqPC1a7yIbI8z81NIKtyI3pgBdEHNPO3r8n2cE9kKl8DWUgo1bh3CWNlYO+jt61On3l6Z0Wbxysqs0XjX4Vjox6h4w7J0GOOCATzw+raWKFlpPp+Xar3cM1qNZN9VOc00HIMxBJTOhT5o5/J
EOF
cat << EOF > $USER
#cloud-config
disable_root: 0
ssh_pwauth:   1
chpasswd:
  list: |
     root:0p3nflight
system_info:
  default_user:
    name: flightadmin
    lock_passwd: true
    gecos: Local Administrator
    groups: [wheel, adm, systemd-journal]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
EOF
mkisofs -o $ISO -V cidata -J $META $USER

echo "Uploading to s3.."
AWSBUCKET=flight-images
aws --region eu-west-2 s3 cp ${ISO} s3://${AWSBUCKET}/metalcontroller_userdata.iso
aws --region eu-west-2 s3api put-object-acl --acl public-read --bucket ${AWSBUCKET} --key metalcontroller_userdata.iso
