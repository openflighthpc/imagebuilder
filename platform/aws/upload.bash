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



cat << EOF > /tmp/image.json
[
  {
    "Description": "${IMAGENAME}",
    "Format": "raw",
    "UserBucket": {
      "S3Bucket": "${AWSBUCKET}",
      "S3Key": "${IMAGENAME}_aws.raw"
    }
  }
]
EOF

aws --region eu-west-2 s3 cp ${INIMAGE} s3://${AWSBUCKET}/${IMAGENAME}_aws.raw 

IMPORT_TASK=$(aws ec2 import-image --architecture x86_64 \
                --region eu-west-2 \
                --description "${IMAGENAME}" \
                --disk-containers "file:///tmp/image.json" \
                --platform Linux \
                --license-type BYOL)
IMPORT_TASK_ID=$(echo "$IMPORT_TASK" |grep ImportTaskId |sed 's/.*: //g;s/"//g')

if [[ "$IMPORT_TASK_ID" == "" ]] ; then
    echo "No import task found, exiting before things go really bad"
    exit 1
fi

while [[ "$(aws ec2 describe-import-image-tasks --region eu-west-2 --import-task-ids $IMPORT_TASK_ID |grep ImageId |awk '{print $2}' |sed 's/"//g;s/,//g')" == "" ]] ; do
    echo "Waiting for import to complete..."
    sleep 30
done

AMI_ID=$(aws ec2 describe-import-image-tasks --region eu-west-2 --import-task-ids $IMPORT_TASK_ID |grep ImageId |sed 's/.*: //g;s/"//g;s/,//g;s/[//g;s/]//g')

echo "Renaming $IMPORT_TASK_ID to ${IMAGENAME}"
aws ec2 copy-image --source-image-id $AMI_ID --source-region eu-west-2 --region eu-west-2 --name ${IMAGENAME} --description ${IMAGENAME}

echo "Removing old AMI"
aws ec2 deregister-image --image-id $AMI_ID --region eu-west-2

