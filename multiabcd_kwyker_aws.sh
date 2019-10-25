#!/bin/bash
#set -eu

echo "abcd_kwyker_aws.sh: Running kwyk container on multiple ABCD S3 file on aws from ~ubuntu/dome.txt"

# This is the main script, that lives on the aws instance itself, that, given
# a file that names multiple S3input - outputfolder pairs, manages its fetch, kwyk run, and 'post' to
# the ReproNim S3 results location
# It expects the local script to put the input file at ~ubuntu/dome.txt
# At the moment it is expecting to run via the AWS-RunShellScript System 
# Management functions, as user = root

# Check usage, 0 argument expected.
if [ "$#" -ne 0 ]; then
  echo "Illegal number of parameters provided"
  echo "Expected usage: multiabcd_kwyker_aws.sh"
  echo "I would terminate"
  exit 10
fi

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

# Loop over ~ubuntu/dome.txt
#cat ~ubuntu/dome.txt | while read -r line
while read -u 10 -r line 
do
  #echo " line = $line"
  #echo "S3_input output_directory pairs ${f1}:${f2} $f3"
  #getme=${f1}:${f2}
  stringarray=($line)
  getme=${stringarray[0]}
  f3=${stringarray[1]}

# Create empty temp directory and go there...
  if [ -d /root/tmp ] ; then
    echo "Project Directory exists, removing it"
    rm -r /root/tmp
  fi
  mkdir /root/tmp
  cd /root/tmp

# Fetch Case
  echo "ABCD Fetching $getme"

# more temporary space
  mkdir tmp

# aws s3 cp command
aws s3 cp ${getme} tmp/down_file.tgz --profile NDA
  if [ $? -ne 0 ] ; then
    echo "Fetch from S3 failed, exiting"
    echo "I would terminate"
    exit 1
  fi

#Unpack ABCD tgz (this case was a simple .nii file... )
  tar xvzf tmp/down_file.tgz -C tmp --strip-components 3

#Get imagefil
  imagefil=`ls tmp/*.nii`
  echo "Image file is $imagefil"
  cp $imagefil anat.nii

# run the kwyk
  echo "Running the kwyk docker"
  docker run -i --rm -v $(pwd):/data neuronets/kwyk:latest-cpu -m bvwn_multi_prior anat.nii output < /dev/null

#Cleanup extra space
  rm -r tmp

# Transfer data out
  echo "Copying data to s3://kwyktest/output/$f3"
  aws s3 cp /root/tmp s3://kwyktest/output/$f3 --recursive --profile reprodnk

# cleanup original tmp
#cd
#rm -r /root/tmp

#end loop
done 10</home/ubuntu/dome.txt

# the end
echo "Done, thanks!"
echo "Terminating"
poweroff
exit 
