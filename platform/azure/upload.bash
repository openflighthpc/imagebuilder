#!/bin/bash
INIMAGE=$IMAGEVHD

AZ_STORAGEACCOUNT="alcesflightimages"
AZ_STORAGECONTAINER="images"

AZ_RESOURCEGROUP="sfn"

AWSBUCKET=flight-images

if [ -z "${IMAGENAME}" ]; then
  IMAGENAME="UNKNOWN"
fi

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! [ -f "${INIMAGE}" ]; then
  echo "Bad input image" >&2
  exit 1
fi

echo "Uploading to AWS s3.." 
aws --region eu-west-2 s3 cp ${INIMAGE} s3://${AWSBUCKET}/${IMAGENAME}_azure.raw

echo "Uploading ${INIMAGE} to Azure as ${IMAGENAME}.."
az storage blob upload --account-name ${AZ_STORAGEACCOUNT}  --container-name ${AZ_STORAGECONTAINER}  --type page --file ${INIMAGE} --name ${IMAGENAME}.vhd
az image create --hyper-v-generation V2 --resource-group ${AZ_RESOURCEGROUP} --name ${IMAGENAME}  --os-type Linux --source https://${AZ_STORAGEACCOUNT}.blob.core.windows.net/${AZ_STORAGECONTAINER}/${IMAGENAME}.vhd
