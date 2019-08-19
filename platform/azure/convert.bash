#!/bin/bash
INIMAGE=$IMAGE
OUTIMAGE=$IMAGEVHD

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
QEMU=${MYDIR}/../../bin/qemu-img

if ! [ -f "${INIMAGE}" ]; then
  echo "Bad input image" >&2
  exit 1
fi

if [ -f "${OUTIMAGE}" ]; then
  echo "Output image exists" >&2
  exit 1
fi

echo "Converting ${INIMAGE} to ${OUTIMAGE}.."
$QEMU convert -p -f raw -O vpc -o subformat=fixed,force_size $INIMAGE $OUTIMAGE
