#!/bin/bash
# Inspired by https://github.com/henrychen95/AWS-AMI-Auto-Backup-None-Amazon-Linux/blob/master/AWS-AMI-Auto-Backup-None-Amazon-Linux.sh 
# and https://github.com/colinbjohnson/aws-missing-tools/blob/master/ec2-automate-backup/Beta/ec2-automate-backup.sh
set -xe

# Intended usage: ec2_create_ami.sh <EC2 Tag name> <EC2 Tag value> <Backup Type>
# For example Name CI or Environment Production
TAGNAME=$1
TAGVALUE=$2
BACKUPTYPE=$3

if [ "$#" -ne 3 ]; then
    echo "Intended usage: iec2_create_ami.sh <EC2 Tag name> <EC2 Tag value> <Backup Type>"
    exit 1
fi

INSTANCEIDS=$(aws ec2 describe-instances --output text --filter Name=tag:"$TAGNAME",Values="$TAGVALUE" --query 'Reservations[*].Instances[*].[InstanceId]')
INSTANCEIDS=($INSTANCEIDS)

for I in "${INSTANCEIDS[@]}"
do
  INSTANCENAME=$(aws ec2 describe-instances --output text --instance-ids "$I" --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value')
  AMIID=$(aws ec2 create-image --output text --instance-id "$I" --name "$INSTANCENAME-$BACKUPTYPE-$(date +"%H%M-%d%m%y")" --no-reboot)
  sleep 30
  SNAPSHOTID=$(aws ec2 describe-images --output text --image-id "$AMIID" --query Images[].BlockDeviceMappings[].Ebs[].[SnapshotId])
  aws ec2 create-tags --resources "$AMIID" --tags Key=Name,Value="$INSTANCENAME"-"$BACKUPTYPE"-"$(date +"%H%M-%d%m%y")"
  aws ec2 create-tags --resources "$AMIID" --tags Key=Type,Value="$BACKUPTYPE"
  aws ec2 create-tags --resources "$SNAPSHOTID" --tags Key=Name,Value="$INSTANCENAME"-"$BACKUPTYPE"-"$(date +"%H%M-%d%m%y")"
  aws ec2 create-tags --resources "$SNAPSHOTID" --tags Key=Type,Value="$BACKUPTYPE"
done