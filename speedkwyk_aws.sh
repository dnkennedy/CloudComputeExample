#!/bin/bash
echo "speedkwyk_aws.sh: Running kwyk container for timing on example case on aws: $filenam"

# This is the main script, that lives on the aws instance itself, that, launches
# the kwyk container run, and 'post' results to
# the named ReproNim S3 results location
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 1 argument expected.
if [ "$#" -ne 1 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: speedkwyk_aws.sh S3_folder_name"
  echo "I would terminate"
  exit 10
fi
basenam=$1

outdir=~ubuntu/speedkwyk

# We are using aws 'profile' for credential management.
# We expect the .aws/configuration file to be pushed from your local system

# move creds from user ubuntu to root
# Create /root/.aws directory if not there...
#if [ ! -d /root/.aws ] ; then
  #echo ".aws Directory dosen't exist, creating"
  #mkdir /root/.aws
#fi
#cp ~ubuntu/.aws/credentials /root/.aws/credentials

# Create empty temp directory and go there...
#if [ -d /root/tmp ] ; then
  #echo "Project Directory exists, removing it"
  #rm -r /root/tmp
#fi
#mkdir /root/tmp
#cd /root/tmp

# using local image file
imfile=~ubuntu/data/anat.nii

# Make output directory, if needed
if [ -d $outdir ] ; then
  echo "Output Directory exists"
else
  echo "Making Output Directory"
  mkdir $outdir
fi

# run the kwyk
echo "Running the kwyk docker"
time docker run -i --rm -v $(pwd):/data neuronets/kwyk:latest-cpu \
  -m bvwn_multi_prior $imfile $outdir/output > $outdir/time.txt

# Transfer data out
echo "Copying result data to s3://speedkwyk/output/$basenam"
aws s3 cp $outdir s3://kwyktest/output/$basenam --recursive --profile reprodnk

# cleanup output tmp
rm -r $outdir

# the end
echo "Done, thanks!"
echo "Terminating"
poweroff
exit 
