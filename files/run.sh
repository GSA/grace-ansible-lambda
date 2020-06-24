#!/bin/bash

apt-get update
apt-get install -y python-pip
pip install awscli

wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

aws s3 cp s3://${bucket}/files/runner.py /tmp/runner.py
chmod +x /tmp/runner.py

python /tmp/runner.py ${bucket} ${role} ${function}