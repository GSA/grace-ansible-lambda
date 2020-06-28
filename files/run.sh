#!/bin/bash

sudo yum -y install awscli
sudo amazon-linux-extras install ansible2 -y

cd /tmp

aws s3 cp --region ${region} --recursive s3://${bucket}/ .

ansible-playbook --private-key ${key_file} -i ${hosts_file} ${site_file}

aws s3 rm --region ${region} s3://${bucket}/ansible_lock

aws ec2 terminate-instances --region ${region} --instance-ids "$(curl http://169.254.169.254/latest/meta-data/instance-id)"