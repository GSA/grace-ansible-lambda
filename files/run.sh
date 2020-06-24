#!/bin/bash

apt-get update
apt-get install -y python-pip
pip install awscli

aws s3 cp s3://${bucket}/files/runner.py /tmp/runner.py
chmod +x /tmp/runner.py

python /tmp/runner.py ${bucket} ${role} ${function}