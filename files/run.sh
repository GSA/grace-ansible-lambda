#!/bin/bash

sudo yum -y install awscli
sudo amazon-linux-extras install ansible2 -y

export AWS_REGION="${region}"

cd /tmp

aws s3 cp --recursive s3://${bucket}/ .

ansible-playbook -i ${hosts_file} ${site_file}

aws s3 rm s3://${bucket}/ansible_lock

aws ec2 terminate-instances --instance-ids "$(curl http://169.254.169.254/latest/meta-data/instance-id)"