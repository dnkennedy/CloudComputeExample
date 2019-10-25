# CloudComputeExample
A repo for an example S3 to EC2 container processing with export back to S3 using 'efficient' local job handling.

A draft GoogleDoc readme is available at: https://docs.google.com/document/d/11Eb6Fp3sD748p3V19m5isem6yCcjpeoAsjWX_1DlCoc/edit?usp=sharing

We start from a super simple problem: a S3 MR image and a container to run on it (abcd_'container'), that we will then look at the generalizations thereof.

The first generalization is to take a list of S3 MR images for analysis with the container (multiabcd_'container').

The following is a quick MD-ification of that prettier document:

## Overview
Efficiency is key in cloud computing. Selecting the most efficient hardware for the job, and handling your machine and machine-job interactions efficiently. In this example, in my clumsy way, I work through an example that I hope will be instructive to others. In this simple example, I hope to illustrate the key points and concepts that need to be solved, one way or another, in any application. My solutions are hacks and one-offs, but I hope that this example is helpful in creating better and more robust core infrastructure for these types of efforts.

I am first writing my example solution as a bash script. It is also clear that support for these types of operations are well served by the **ReproMan** (https://github.com/ReproNim/reproman) initiative. That approach, while powerful, requires the knowledge of some extra (but important) concepts that at first may detract from the first objective. So, the **ReproMan** way to do this better is left as a second chapter.

I will take as my objective a simple processing example. I am targeting an ABCD-specific use case, where the data release resides on the AWS S3. This should be readily extendable to other S3 sources, such as HCP and INDI, etc. as well as non-S3 sources. I am also intentionally targeting processing jobs that can be run as a ‘container’ to start. This assumption eases some constraints, and should be readily accessible to many current neuroimaging data analysis applications. This constraint is also not absolute, and solutions for non-containerized applications are easily envisioned.

## The Example Workflow
At the simplest level, I envision the example problem as: 
* Given an S3 image link ($S3image) and 
* Given a Docker or Singularity container to run (for example https://hub.docker.com/r/neuronets/kwyk), 
* Run the container on the image on an AWS EC2 cloud instance and 
* Put the result back into an S3 storage location.

## The Mechanics
Since efficiency is one of the prime objectives, we want to minimize any human/physical interactions with the AWS EC2 instance (since we are paying for it from its launch to its termination). Our objective it to
1. Launch instance
1. Transmit any needed operational information to instance
1. Copy data to instance
1. Run process
1. Copy results off instance
1. Terminate instance

as efficiently as possible. We envision step 1) and 2) being managed from your local computer, and steps 3)-6) being run ‘autonomously’ on the running EC2 instance.
Thus, in my example, we will work with 2 scripts, in this case called: abcd_kwyker_awslocal.sh and abcd_kwyker_aws.sh where the \*_awslocal.sh runs and controls the process launch from your local computer, and the \*_aws.sh is the script resigned to control your processing steps and to run on the running EC2 instance itself.

## Details, awslocal.sh
Ultimately, there are a small handful of things the ‘local’ script needs to know:
1. The S3 address of the image we want to process
1. Where (what S3 bucket) to put the result
1. What processing script we want to run on the EC2 instance
1. What EC2 instance we want to use
1. How to authenticate your permissions (to data and compute)

**1 & 2**: In my example, we pass the S3 address and output bucket in as the first two parameters to the script:
> s3filenam=$1

> basenam=$2

**3**: I hardcoded the aws EC2 processing script locally as: “abcd_kwyker_aws.sh” and that it resides in “~/bin/”.

**4**: I have hard coded the AMI of the EC2 instance I want as: 
> IID=i-00c6af722eee5851b

This is a NITRC-CE-LITE_ABCD machine with the necessary tools installed for this example (docker, AWS CLI). It is currently configured as “m5.4xlarge” (16 vCPU). For this exercise, I will work with this configuration that takes about 8 minutes to run on a typical ABCD T1-weighted structural scan; generalization to different instance configurations can be easily envisioned. And detailed machine design and selection is a whole important topic of its own that I don’t want to get distracted with here.

**5**: Authentication. This is a very variable and fluid topic. I’ll tell you what I did, but this is probably non-optimal, and will definitely be changing. There are two types of things I am authenticating: my NDA access permissions to the S3 imaging data; and my personnel permissions to controlling the EC2 instance and the S3 output bucket. For my NDA access, I use a two-step process (which we can discuss elsewhere) to add my ‘NDA’ persona (access, secret_access, and session_token) to my “~/.aws/credentials” file. For AWS EC2 command line operations, I can then use “--profile NDA”. I also have my own personal AWS credentials in a ‘persona’ entitled “reprodnk”; I can then use “--profile reprodnk” for operations (EC2 manipulations and output S3 copy). In addition, my personal authentication to my AWS instances can be validated by the ‘.pem’ file associated with my running instance.  Note, in this current setup, my NDA session token is only valid for 24 hours and then need to be renewed, making sure your NDA persona is up to date when this local script is launched I’ll leave up to the user…

Thus, once these inputs are handled, we:
1. ‘Launch’ the desired instance, and await its readiness
1. Copy credential file and script to run to the instance
1. Direct the instance to run the named script

**1**: Launch and monitor via AWS CLI:

> aws ec2 start-instances --instance-ids $IID --profile reprodnk

> aws ec2 wait instance-status-ok --instance-ids $IID --profile reprodnk

**2**: Linux SCP commands:

> #Push Creds to instance

> scp -i DNK_CRNC.pem ~/.aws/credentials ubuntu@${IP}:~/.aws/.

> #push script to instance

> scp -i DNK_CRNC.pem ~/bin/abcd_kwyker_aws.sh ubuntu@${IP}:~/bin/.

**3**: Execution directive via aws ssm (reuired that the instance has its ‘ssm’ awareness turned on:

> aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" \
 --instance-ids "$IID" --parameters "commands=~ubuntu/bin/abcd_kwyker_aws.sh $s3filenam $basenam" \
 --timeout-seconds "600" --max-concurrency "50" --max-errors "0" \
 --output-s3-bucket-name "kwyktest" --region us-east-1 --profile reprodnk

***Note:*** Be careful about ‘zones’. The S3 ABCD content is in the “us-east-1”. In the current application, make sure that your computational instance is in the same zone. Data transfer costs from S3 to EC2 is fast and free, as long as it is within zone.

Details, aws.sh
The aws-side operations are relatively straightforward and are encoded in the script to be run on the instance::
1. Copy the named S3 data to a tmp directory in the instance 
1. Launch the analysis ‘container’
1. Copy the results to a named S3 bucket
1. ‘Terminate’ the running instance

**1**: I accomplish with the AWS commandline interface (CLI):

> aws s3 cp $S3filenam tmp --profile NDA

**2**: Docker run as:
    
> docker run -i --rm -v $(pwd):/data neuronets/kwyk:latest-cpu -m bvwn_multi_prior input output

**3**: Again, AWS CLI:
  
> aws s3 cp output s3://kwyktest/output/$basenam --recursive --profile reprodnk

**4**: And finally, the linux ‘poweroff’ command. Note: ‘poweroff’ puts the instance into an AWS ‘stop’ state. It no longer accumulates execution charges, but the basic computer system persists (and thus can be re-manipulated for state and machine type, for example) and will accumulate some storage costs. Extensions to this protocol to put the computer state into a user selected final state.


## Putting it Together
In my example, the processing is executed in the following fashion:

> abcd_kwyker_awslocal.sh \ s3://NDAR_Central_2/submission_14921/NDARINVARWXFNJF_baselineYear1Arm1_ABCD-MPROC-T1_20170811130118.tgz \
NDARINVARWXFNJF_baselineYear1Arm1_ABCD-MPROC-T1_20170811130118_v9

Remember, this presupposes my [NDA] persona is up to date, that my AWS instance exists (but not necessarily running), my personal AWS persona (reprodnk, in this example) is valid, I have the .pem file associated with my instance and I have a S3 bucket called ‘kwyktest’.

This command (at the moment) only needs the S3 link to an input dataset, and an output directory name. In this case, I’m reusing the base imaging name as my output file name, in order to maintain the ‘provenance’ of this result in terms of what image file this container was run on.

The local script completes after successful transmission of the processing command to the AWS instance. The remote process runs for about 8 minutes in this specific example. The instance ‘stops’ upon completion, but as yet we do not provide notification back to the executioner, which is an addition that should be made. So, at the moment, you can monitor your EC2 console to verify completion.  Additional safeguards should be added to proven runaway instances in the more complete version of this.

# Multiple inputfiles/outputdirectories
The multiabcd_kwyk_{aws,awslocal}.sh scripts takes an input file (as an input to the multiabcd_kwyk_awslocal.sh). Thie file is includes an S3 path and output S3 path pair per line. The AWS instance will run and output each of these lines prior to terminating.
