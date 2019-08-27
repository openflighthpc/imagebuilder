#!/bin/bash

if [ -z "${IMAGENAME}" ]; then
  export IMAGENAME=CENTOS7BASE`date +%d%m%y%H%M`
fi

export DEVICE=`losetup -f`
export ROOTFS=/rootfs
export IMAGE=/tmp/VHD.img
export IMAGEVHD=/tmp/VHD.vhd
export PLATFORM=azure
export BASEIMAGE=/mnt/BASE.img

if [ -f /var/run/imager.pid ]; then
  echo "Someone is already running me, or delete /var/run/imager.pid" >&2
  exit 1
fi

echo $$ > /var/run/imager.pid

rm -fv $IMAGE
rm -fv $IMAGEVHD

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -f "${BASEIMAGE}" ]; then
  echo "Baseimage detected at ${BASEIMAGE} - copying that.."
  rsync -pa --sparse ${BASEIMAGE} ${IMAGE} > /dev/null
else
  echo "No Baseimage found - building a new one" 
  {
    bash -e ${MYDIR}/build/buildimage.bash
  } || { 
    echo "Build failed!" >&2
    bash ${MYDIR}/build/cleanup.bash
    rm /var/run/imager.pid
    exit 1
  }
fi

if ! [ -z "${PLATFORM}" ]; then
  {
    bash -e ${MYDIR}/build/chrootrun.bash ${MYDIR}/platform/${PLATFORM}/platform.bash /tmp/imageplatform.log
  } || {
    echo "Platform run failed!" >&2
    rm /var/run/imager.pid
    exit 1
  }
fi

if ! [ -z "${CUSTOMSCRIPT}" ]; then
  {
    bash -e ${MYDIR}/build/chrootrun.bash ${CUSTOMSCRIPT} /tmp/imagecustom.log
  } || {
    echo "Custom run failed!" >&2
    rm /var/run/imager.pid
    exit 1
  }
fi

{
  bash -e ${MYDIR}/build/chrootrun.bash ${MYDIR}/scripts/cleanup.bash /tmp/imagecleanup.log
} || {
  echo "Cleanup run failed!" >&2
  rm /var/run/imager.pid
  exit 1
}

if ! [ -z "${PLATFORM}" ]; then
  {  
    bash -e ${MYDIR}/platform/${PLATFORM}/convert.bash
  } || {
    echo "Convert failed!" >&2
    rm /var/run/imager.pid
    exit 1
  }
  {
    bash -e ${MYDIR}/platform/${PLATFORM}/upload.bash
  } || {
    echo "Upload failed!" >&2
    rm /var/run/imager.pid
    exit 1
  }
fi

rm /var/run/imager.pid
