#!/bin/bash

if [ -z "${SQUASHSTAGE}" ]; then
  echo "Please give me a squash staging dir" >&2
  exit 1
fi


mkdir -p ${SQUASHSTAGE}/LiveOS/
echo "Copying image onto squashfs stage.."
rsync -pa --sparse $IMAGE ${SQUASHSTAGE}/LiveOS/ext3fs.img

echo "Squashing.."
mksquashfs ${SQUASHSTAGE}/ ${IMAGESQUASH}

