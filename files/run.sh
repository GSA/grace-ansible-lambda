#!/bin/bash

export ANSIBLE_HOST_KEY_CHECKING=false

sudo yum -y install awscli python-boto3
sudo amazon-linux-extras install ansible2 -y

cd /tmp

aws s3 cp --region ${region} --recursive s3://${bucket}/ .

aws s3 cp --region ${region} s3://${bucket}/files/id_rsa ${key_file}
chown 400 ${key_file}

# aws s3 cp --region ${region} s3://${bucket}/files/python-xmltodict-0.9.0-1.el7.noarch.rpm python-xmltodict-0.9.0-1.el7.noarch.rpm
# rpm -i /tmp/python-xmltodict-0.9.0-1.el7.noarch.rpm

# aws s3 cp --region ${region} s3://${bucket}/files/python2-ntlm-auth-1.1.0-1.el7.noarch.rpm python2-ntlm-auth-1.1.0-1.el7.noarch.rpm
# rpm -i /tmp/python2-ntlm-auth-1.1.0-1.el7.noarch.rpm

# aws s3 cp --region ${region} s3://${bucket}/files/python2-requests_ntlm-1.1.0-1.el7.noarch.rpm python2-requests_ntlm-1.1.0-1.el7.noarch.rpm
# rpm -i /tmp/python2-requests_ntlm-1.1.0-1.el7.noarch.rpm

# aws s3 cp --region ${region} s3://${bucket}/files/python2-winrm-0.3.0-1.el7.noarch.rpm python2-winrm-0.3.0-1.el7.noarch.rpm
# rpm -i /tmp/python2-winrm-0.3.0-1.el7.noarch.rpm

aws s3 cp --region ${region} s3://${bucket}/files/create_secrets.py create_secrets.py

AWS_DEFAULT_REGION=${region} python create_secrets.py

mkdir -p /tmp/ansible/callback_plugins

aws s3 cp --region ${region} s3://${bucket}/files/plugin.py /tmp/ansible/callback_plugins/plugin.py

# If /tmp/ansible/.env exists, then export all variables excluding lines beginning with #
[ -f /tmp/ansible/.env ] && export $(egrep -v '^#' /tmp/ansible/.env | xargs)

ansible-playbook -v --private-key ${key_file} -u ${ec2_user} -e @/tmp/ansible/secrets.yaml -i ${hosts_file} ${site_file}

instance=$(curl http://169.254.169.254/latest/meta-data/instance-id)

aws s3 cp --region ${region} /var/log/cloud-init-output.log "s3://${bucket}/logs/run-$${instance}.log"

aws ec2 terminate-instances --region ${region} --instance-ids $instance