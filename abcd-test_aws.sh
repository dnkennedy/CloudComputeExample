#!/bin/bash

echo "abcd-test_aws.sh: Running dcanlabs/abcd-hcp-pipeline in test mode container on ABCD S3 BIDS case on aws"

# This is the main script, that lives on the aws instance itself, that, given
# the S3 path to an anatomic case, manages its fetch, kwyk run, and 'post' to
# the ReproNim S3 results location
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 1 argument expected.
if [ $# -ne 1 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: abcd-test_aws.sh Output_Basename"
  echo "I would terminate"
  exit 10
fi
basenam=$1
bucket=abcd-test/output
localdir=abcd-test

# We are using aws 'profile' for credential management.
# We expect the .aws/configuration file to be pushed from your local system

# move creds from user ubuntu to root
#cp ~ubuntu/.aws/credentials /root/.aws/credentials

# Clear Prior BIDS directory, if present...
if [ -d ~ubuntu/BIDS ] ; then
  echo "BIDS Directory exists, removing it"
  rm -r ~ubuntu/BIDS
fi

# Fetch Case
echo "ABCD Fetching BIDS"
python3 ~ubuntu/nda-abcd-s3-downloader/download.py -o ~ubuntu/BIDS \
	-s ~ubuntu/$localdir/subj.txt \
	-i ~ubuntu/$localdir/datastructure_manifest.txt \
	-l ~ubuntu/nda-abcd-s3-downloader/log/ \
	-d ~ubuntu/$localdir/subsets.txt

# Prepare output directory
if [ -d ~ubuntu/DCAN ] ; then
  echo "DCAN Directory exists, removing it"
  rm -r sudo ~ubuntu/DCAN
fi
mkdir ~ubuntu/DCAN

# Run Container
docker run --rm -v /home/ubuntu/BIDS:/bids_input:ro \
	-v /home/ubuntu/DCAN:/output -v /home/ubuntu/$localdir/license.txt:/license \
	dcanlabs/abcd-hcp-pipeline /bids_input /output \
	--freesurfer-license=/license --print-commands-only >>\
       	/home/ubuntu/DCAN/log

# Transfer data out
echo "Copying result to s3://abcd_test/output/$basenam"
aws s3 cp ~ubuntu/DCAN s3://${bucket}/$basenam --recursive --profile reprodnk

# cleanup original tmp
sudo rm -r ~ubuntu/DCAN
sudo rm -r ~ubuntu/BIDS

# the end
echo "Done, thanks!"
#echo "Terminating"
#poweroff
exit 
