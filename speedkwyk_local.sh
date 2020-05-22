#!/bin/bash
set -eu

echo "speedkwyk_local: Running kwyk container on EC2 resource on test case - local controller"
echo "For NITRC Speed tests"

# This is the main script, for local management of the analysis process, that, given
# an instance type, manages a kwyk run for timing, and 'post' of results to
# the named ReproNim S3 results location
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 2 argument expected.
if [ "$#" -ne 2 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: speedkwyk_local.sh AWSEC2_instance_type outputdirectoryname" 
  exit 10
fi

# setup variables
itype=$1
basenam=$2

# Identify AWS EC2 instance ID 
# prepare this instance to have the test dataset available, assumed
IID=i-0e8750dd1c7e02355

# Script to run on the remoth instance
# Path 
localscriptpath=~/GitHub/CloudComputeExample
# Script name
remotescript=speedkwyk_aws.sh

# Location for script on remote instance
remotescriptpath=~ubuntu/bin

# We are using aws 'profile' for credential management.
# We expect the .aws/configuration file to be pushed from your local system (i.e. here)

# Make sure instance is stopped

# Set Instance type
aws ec2 modify-instance-attribute --instance-id $IID --instance-type "{\"Value\": \"$itype\"}"

# Start Instance
echo "Launching and waiting"
echo "IID = $IID"
aws ec2 start-instances --instance-ids $IID --profile reprodnk 
aws ec2 wait instance-status-ok --instance-ids $IID --profile reprodnk

#Get ip, $IP and instanceID
echo "Get ip of instance"
IP=`aws ec2 describe-instances --instance-ids $IID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text --profile reprodnk`
echo "Found IP as $IP"

# Push stuff to instance
# Since this speed test is always the same details for run, let's assume we can 
# pre-load all the relevant stuff there. What stuff, you ask:
# The creds
# scp -o StrictHostKeyChecking=no -i ~/DNK_CRNC.pem ~/.aws/credentials ubuntu@${IP}:~/.aws/.

# The script
# scp -i ~/DNK_CRNC.pem ${localscriptpath}/$remotescript ubuntu@${IP}:${remotescriptpath}/.

# Launch process on instance

echo "commands=${remotescriptpath}/$remotescript $s3filenam $basenam"

aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" \
 --instance-ids "$IID" --parameters "commands=${remotescriptpath}/$remotescript $s3filenam $basenam" \
 --timeout-seconds "600" --max-concurrency "50" --max-errors "0" \
 --output-s3-bucket-name "speedkwyk" --region us-east-1 --profile reprodnk

# the end
echo "Your process has been launched.  The instance will stop itself upon "
echo "completion. But, make sure to check in on it as needed to make sure!"
echo "Done, thanks!"
exit 
