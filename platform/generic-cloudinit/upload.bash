#!/bin/bash
INIMAGE=${IMAGE}
AWSBUCKET=flight-images


if [ -z "${IMAGENAME}" ]; then
  IMAGENAME="UNKNOWN"
fi

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! [ -f "${INIMAGE}" ]; then
  echo "Bad input image - ${INIMAGE}" >&2
  exit 1
fi

echo "Uploading to s3.."
aws --region eu-west-2 s3 cp ${INIMAGE} s3://${AWSBUCKET}/${IMAGENAME}_generic-cloudinit.raw 
aws --region eu-west-2 s3api put-object-acl --acl public-read --bucket ${AWSBUCKET} --key ${IMAGENAME}_generic-cloudinit.raw

