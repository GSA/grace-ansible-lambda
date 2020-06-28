#!/bin/bash

sudo yum -y install awscli
sudo amazon-linux-extras install ansible2 -y

cd /tmp

aws s3 cp --region ${region} --recursive s3://${bucket}/ .

ansible-playbook --private-key ${key_file} -u ${ec2_user} -i ${hosts_file} ${site_file}

aws s3 rm --region ${region} s3://${bucket}/ansible_lock

instance=$(curl http://169.254.169.254/latest/meta-data/instance-id)

aws s3 cp --region ${region} /var/log/clout-init-output.log "logs/run-$${instance}.log"

aws ec2 terminate-instances --region ${region} --instance-ids $instance