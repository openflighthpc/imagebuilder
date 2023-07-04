#!/bin/bash 

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Recreate initramfs
if [ ${DISTROMAJOR} -eq 8 ]; then
  KVER=$(echo /boot/vmlinuz-4* | cut -f2- -d'-')
else
  KVER=$(echo /boot/vmlinuz-3* | cut -f2- -d'-')
fi
dracut -N -v -f /boot/initramfs-${KVER}.img ${KVER}

