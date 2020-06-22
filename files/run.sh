#!/bin/bash

# Uncomment the next line to exit on error
# set -e

echo "installing Ansible"
# do stuff

echo "mounting S3 bucket with Ansible content"
mkdir -p /ansible
s3fs -o iam_role="${role}",bucket="${bucket}" /ansible

echo "starting Ansible execution"
# do stuff

echo "requesting cleanup of this EC2 instance"
# do stuff
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

CRED=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v "http://169.254.169.254/latest/meta-data/iam/security-credentials/${role}"`

