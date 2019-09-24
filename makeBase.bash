#!/bin/bash -e

if [ -z "${IMAGENAME}" ]; then
  export IMAGENAME=BASE-`date +%d%m%y%H%M`
else
  export IMAGENAME="${IMAGENAME}"-`date +%d%m%y%H%M`
fi

export DEVICE=`losetup -f`
export ROOTFS=/rootfs
export IMAGE=/tmp/VHD.img
export IMAGEVHD=/tmp/VHD.vhd
export SQUASHSTAGE=/tmp/squashstage/
export IMAGESQUASH=/tmp/VHD.squash
export SUPPORTPACK=/tmp/supportpack.tgz
if [ -z "${ACTION}" ]; then
  export ACTION='build'
else
  export ACTION
fi

if [ -z "${PLATFORM}" ]; then
  PLATFORM=azure
fi

if [ "${PLATFORM}" == 'live' ]; then
  BOOTABLE=0
else
  BOOTABLE=1
fi

if ! [ -z "${SKIPUPLOAD}" ]; then
  export SKIPUPLOAD=1
fi

export BOOTABLE
export PLATFORM
export BASEIMAGE=/mnt/BASE.img

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! [ -z "${CUSTOMSCRIPT}" ]; then
  if ! [ -f "${CUSTOMSCRIPT}" ]; then
    echo "Can't locate customescript file - assuming its a link and attempting to download it"
    curl "${CUSTOMSCRIPT}" > /tmp/customscript.bash
    if [ $? -ne 0 ]; then
      "Can't download ${CUSTOMSCRIPT}.." >&2
      exit 1
    fi
    CUSTOMSCRIPT=/tmp/customscript.bash
  fi
fi
export CUSTOMSCRIPT

if [ -f /var/run/imager.pid ]; then
  echo "Someone is already running me, or delete /var/run/imager.pid" >&2
  exit 1
fi

echo $$ > /var/run/imager.pid


if [ "${ACTION}" == 'build' ]; then
  rm -fv $IMAGE
  rm -fv $IMAGEVHD
  rm -fv $IMAGESQUASH
  rm -rfv $SQUASHSTAGE
  rm -fv $SUPPORTPACK

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

  if ! [ -z "${PLATFORM}" ] && ! [ "${SKIPUPLOAD}" -eq 1 ]; then
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
elif [ "${ACTION}" == 'chroot' ]; then
{
  bash -e ${MYDIR}/build/chrootrun.bash 'bash'
}
else
{ 
  echo "Unrecognised action - ${ACTION}" >&2
  rm /var/run/imager.pid
  exit 1
}
fi
rm /var/run/imager.pid
