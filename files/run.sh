#!/bin/bash

sudo yum -y install unzip
sudo yum -y install awscli
sudo amazon-linux-extras install ansible2 -y

outputFile="/tmp/grace-ansible-runner.zip"
binaryFile="/tmp/grace-ansible-runner"

sudo aws s3 cp s3://${bucket}/${key} /tmp/

export REGION="${region}"
export BUCKET="${bucket}"
export FUNC_NAME="${function}"
export HOSTS_FILE="${hosts_file}"
export SITE_FILE="${site_file}"

cd /tmp
unzip $outputFile
chmod +x $binaryFile
$binaryFile