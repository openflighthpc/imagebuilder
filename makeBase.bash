#!/bin/bash

export IMAGENAME=CENTOS7BASE`date +%d%m%y%H%M`
export DEVICE=`losetup -f`
export ROOTFS=/rootfs
export IMAGE=/tmp/VHD.img
export IMAGEVHD=/tmp/VHD.vhd
export PLATFORM=aws

rm -fv $IMAGE
rm -fv $IMAGEVHD

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

{
  bash -e ${MYDIR}/build/buildimage.bash
} || { 
  echo "Build failed!" >&2
  bash ${MYDIR}/build/cleanup.bash
  exit 1
}
{  
  bash -e ${MYDIR}/platform/${PLATFORM}/convert.bash
} || {
  echo "Convert failed!" >&2
  exit 1
}
{
  bash -e ${MYDIR}/platform/${PLATFORM}/upload.bash
} || {
  echo "Upload failed!" >&2
  exit 1
}
