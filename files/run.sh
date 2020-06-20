#!/bin/bash

# Uncomment the next line to exit on error
# set -e

echo "installing ansible"
# do stuff

echo "mounting S3 bucket with Ansible content"
mkdir -p /ansible
s3fs -o iam_role="${role}",bucket="${bucket}" /ansible

echo "starting ansible execution"
# do stuff

echo "requesting cleanup of this EC2 instance"
# do stuff