#!/bin/bash
set -eu

echo "abcd_kwyker_awslocal: Running kwyk container on EC2 resource on ABCD S3 file on aws - local controller"

# This is the main script, for local management of the analysis process, that, given
# the S3 path to an anatomic case, manages its fetch, kwyk run, and 'post' to
# the named ReproNim S3 results location
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 2 argument expected.
if [ "$#" -ne 2 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: abcd_kwyker_aws.sh S3_file_name outputdirectoryname" 
  exit 10
fi

# setup variables
s3filenam=$1
basenam=$2

#IID=i-00c6af722eee5851b
IID=i-0e8750dd1c7e02355
remotescript=abcd_kwyker_aws.sh
localscriptpath=~/bin
remotescriptpath=~ubuntu/bin

# We are using aws 'profile' for credential management.
# We expect the .aws/configuration file to be pushed from your local system (i.e. here)

# TODO insert a checker to see if you have a valid and currently active 
# session token, and to provide appropriate instructions if you don't...
# There are two points here: 1) we want the 'on aws' activities to be completly
# 'hands-off' for efficiency purposes; and 2) we'd like to not have the user 
# entering their NDA authorization very often.

# IF creds fail, then do the following:
#PrepCreds (if needed) will result in an .aws/credentials file
#Get token content into /Users/davidkennedy/downloadmanager/tempcred.txt
#docker run -it --rm -v $NDAdir:/data debian /data/debian_generate_token.sh $NDAuser $NDApasswd

#Patch AWS Creds
#~/bin/prep_creds.sh $NDAuser

# Start Instance
echo "Launching and waiting"
echo "IID = $IID"
aws ec2 start-instances --instance-ids $IID --profile reprodnk 
#aws ec2 wait instance-running --instance-ids $IID --profile reprodnk
aws ec2 wait instance-status-ok --instance-ids $IID --profile reprodnk

#Get ip, $IP and instanceID
echo "Get ip of instance"
IP=`aws ec2 describe-instances --instance-ids $IID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text --profile reprodnk`
echo "Found IP as $IP"

#Push Creds to instance
scp -o StrictHostKeyChecking=no -i ~/DNK_CRNC.pem ~/.aws/credentials ubuntu@${IP}:~/.aws/.

#push script to instance
scp -i ~/DNK_CRNC.pem ${localscriptpath}/$remotescript ubuntu@${IP}:${remotescriptpath}/.

# Launch process on instance

echo "commands=${remotescriptpath}/$remotescript $s3filenam $basenam"

aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" \
 --instance-ids "$IID" --parameters "commands=${remotescriptpath}/$remotescript $s3filenam $basenam" \
 --timeout-seconds "600" --max-concurrency "50" --max-errors "0" \
 --output-s3-bucket-name "kwyktest" --region us-east-1 --profile reprodnk

# the end
echo "Your process has been launched.  The instance will stop itself upon "
echo "completion. But, make sure to check in on it as needed to make sure!"
echo "Done, thanks!"
exit 
