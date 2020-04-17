#!/bin/bash

echo "abcd_fprep_aws.sh: Running fmriprep container on ABCD S3 BIDS case on aws: $filenam"

# This is the main script, that lives on the aws instance itself, that, given
# the S3 path to an anatomic case, manages its fetch, kwyk run, and 'post' to
# the ReproNim S3 results location
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 3 argument expected.
if [ "$#" -ne 3 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: abcd_fprep_aws.sh subject S3_BIDS_basepath S3_result_folder_name"
  echo "I would terminate"
  exit 10
fi
subject=$1
s3bidsbase=$2
basenam=$3

# We are using aws 'profile' for credential management.
# We expect the .aws/configuration file to be pushed from your local system

# move creds from user ubuntu to root
cp ~ubuntu/.aws/credentials /root/.aws/credentials

# TODO insert a checker to see if you have a valid and currently active 
# session token, and to provide appropriate instructions if you don't...
# There are two points here: 1) we want the 'on aws' activities to be completly
# 'hands-off' for efficiency purposes; and 2) we'd like to not have the user 
# entering their NDA authorization very often.

# If Cred_Check fails, instruct user to do prep_cred on their local system 
# Local prep_creds pushed credential file up to the AWS instance. This should 
# be checked locally before we even get here, so hopefully this should not fail...

# Create empty temp directory and go there...
if [ -d /root/tmp ] ; then
  echo "Project Directory exists, removing it"
  rm -r /root/tmp
fi
mkdir /root/tmp
cd /root/tmp

# Fetch Case
echo "BIDS Fetching $s3filenam"

# more temporary space
#mkdir tmp
mkdir sub-${subject}

# aws s3 cp command
#aws s3 cp $s3filenam tmp/down_file.tgz --profile NDA
aws s3 cp $s3bidsbase/sub-${subject}/  sub-${subject}/. —profile reprodnk --recursive
if [ $? -ne 0 ] ; then
    echo "Fetch from S3 failed, exiting"
    echo "I would terminate"
    exit 1
fi

# get the necessary BIDS supporet files
aws s3 cp $s3bidsbase/participants.tsv . —profile reprodnk
aws s3 cp $s3bidsbase/dataset_description.json . —profile reprodnk


#Unpack ABCD tgz (this case was a simple .nii file... )
tar xvzf tmp/down_file.tgz -C tmp --strip-components 3

#Get imagefil
imagefil=`ls tmp/*.nii`
echo "Image file is $imagefil"
cp $imagefil anat.nii

#dcm2niix
#Not needed in this case...

# run the kwyk
echo "Running the kwyk docker"
docker run -i --rm -v $(pwd):/data neuronets/kwyk:latest-cpu -m bvwn_multi_prior anat.nii output 

#Cleanup extra space
rm -r tmp

# Transfer data out
echo "Copying data to s3://kwyktest/output/$basenam"
aws s3 cp /root/tmp s3://kwyktest/output/$basenam --recursive --profile reprodnk

# cleanup original tmp
#cd
#rm -r /root/tmp

# the end
echo "Done, thanks!"
echo "Terminating"
poweroff
exit 