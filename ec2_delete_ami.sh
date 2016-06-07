#!/bin/bash
# Inspired by https://github.com/henrychen95/AWS-AMI-Auto-Backup-None-Amazon-Linux/blob/master/AWS-AMI-Auto-Backup-None-Amazon-Linux.sh 
# and https://github.com/colinbjohnson/aws-missing-tools/blob/master/ec2-automate-backup/Beta/ec2-automate-backup.sh
set -xe

# Intended usage: ec2_delete_ami.sh <Backup Type> <Retention>
# Retention in days e.g. 14d / 14days, weeks e.g. 4w / 4weeks or months e.g. 12m/12months
# ec2_delete_ami.sh Daily 14d
BACKUPTYPE=$1
RETENTION=$2

if [ "$#" -ne 2 ]; then
    echo "Intended usage: ec2_delete_ami.sh <Backup Type> <Retention>"
    exit 1
fi

case $RETENTION in
  #any number of numbers followed by a letter "d" or "days" multiplied by 1440 (number of seconds in a day)
  [0-9]*d) UNIXRETENTION=$(( ${RETENTION%?} * 1440 )) ;;
  #any number of numbers followed by a letter "w" or "weeks" multiplied by 10080 (number of seconds in an week)
  [0-9]*w) UNIXRETENTION=$(( ${RETENTION%?} * 10080 )) ;;
  #any number of numbers followed by a letter "m" or "months" multiplied by 43200 (number of seconds in a 30 day month)
  [0-9]*m) UNIXRETENTION=$(( ${RETENTION%?} * 43200 ));;
  #no trailing digits default is days - multiply by 86400 (number of seconds in a day)
  *) UNIXRETENTION=$(( ${RETENTION%?} * 1440 ));;
esac

AMIIDS=$(aws ec2 describe-images --owner self --output text --filter Name=tag:Type,Values="$BACKUPTYPE" --query Images[].ImageId[])
AMIIDS=($AMIIDS)

for I in "${AMIIDS[@]}"
do
  CREATIONDATE=$(aws ec2 describe-images --output text --image-id "$I" --filter Name=tag:Type,Values="$BACKUPTYPE" --query Images[].CreationDate[])
  SNAPSHOTID=$(aws ec2 describe-images --output text --image-id "$I" --query Images[].BlockDeviceMappings[].Ebs[].[SnapshotId])
  UNIXCREATIONDATE=$(date -d "$CREATIONDATE" +"%s")
  UNIXCURRENTDATE=$(date +%s)
  AGE=$(( UNIXCURRENTDATE - UNIXCREATIONDATE ))
  if [[ $AGE -gt $UNIXRETENTION ]]; then
    aws ec2 deregister-image --image-id "$I"
    aws ec2 delete-snapshot --snapshot-id "$SNAPSHOTID"
  fi
done
