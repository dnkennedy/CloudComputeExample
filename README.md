# CloudComputeExample
A repo for an example S3 to EC2 container processing with export back to S3 using 'efficient' local job handling.

A draft GoogleDoc readme is available at: https://docs.google.com/document/d/11Eb6Fp3sD748p3V19m5isem6yCcjpeoAsjWX_1DlCoc/edit?usp=sharing

Overtime, that content will be incorporate into this document.

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
