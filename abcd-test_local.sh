#!/bin/bash
set -eu

echo "abcd-test_local: Running DCAN_test-mode container on EC2 resource on ABCD BIDS data on aws - local controller"

# This is the local script, for local management of the analysis process.
# Given the 'subjects' and 'data classes' as input to the nda_abcd-s3-downloader
# it fetchs data, rund DCAN process, and posts results to the named ReproNim 
# S3 results location.
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 2 argument expected.
if [ "$#" -ne 2 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: abcd-test_local.sh source_directory outputdirectoryname" 
  exit 10
fi

# setup variables
sourcedir=$1      # local directory with the parameter files
basenam=$2        # S3 bucket name for output (will live in S3://abcd-test/output/*

# Identify AWS EC@ instance ID
IID=i-0e8750dd1c7e02355

remotescript=abcd-test_aws.sh    # script to run on the remove instance
localscriptpath=~/GitHub/CloudComputeExample  # local path for the remote script
remdir=~ubuntu/abcd-test     # Directory for stuff on the EC2

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
aws ec2 wait instance-status-ok --instance-ids $IID --profile reprodnk

#Get ip, $IP and instanceID
echo "Get ip of instance"
IP=`aws ec2 describe-instances --instance-ids $IID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text --profile reprodnk`
echo "Found IP as $IP"

# Push stuff to instance
# Assuming (for now) remote dir exists and contains manifest
# make sure to include this requirement in the instructions
echo "Pushing stuff"

# Creds 
scp -o StrictHostKeyChecking=no -i ~/DNK_CRNC.pem ~/.aws/credentials ubuntu@${IP}:~/.aws/.

# script
scp -p -i ~/DNK_CRNC.pem ${localscriptpath}/$remotescript ubuntu@${IP}:${remdir}/.

# Manifest file (assuming it's there for now, during EC2 setup, but should check)
#scp -i ~/DNK_CRNC.pem ${sourcedir}/datastructure_manifest.txt ubuntu@${IP}:${remdir}/.

# Subjects
scp -i ~/DNK_CRNC.pem ${sourcedir}/subj.txt ubuntu@${IP}:${remdir}/.

# Subsets
scp -i ~/DNK_CRNC.pem ${sourcedir}/subsets.txt ubuntu@${IP}:${remdir}/.

# FS License
scp -i ~/DNK_CRNC.pem ${sourcedir}/license.txt ubuntu@${IP}:${remdir}/.

# Launch process on instance
echo "commands=${remdir}/$remotescript $basenam"

aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" \
 --instance-ids "$IID" --parameters "commands=$remdir/$remotescript $basenam" \
 --timeout-seconds "600" --max-concurrency "50" --max-errors "0" \
 --output-s3-bucket-name "abcd-test" --region us-east-1 --profile reprodnk

# the end
echo "Your process has been launched.  The instance will stop itself upon "
echo "completion. But, make sure to check in on it as needed to make sure!"
echo "Done, thanks!"
exit 
