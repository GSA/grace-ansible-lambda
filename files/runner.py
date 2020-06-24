#!/usr/bin/python

import os
import sys
import requests
import logging
import boto3
import json


logger = logging.getLogger(__name__)

EC2_METADATA_URL_BASE = 'http://169.254.169.254'

def main():
    bucket   = '${bucket}'
    role     = '${role}'
    function = '${function}'

    deps()

    # Execute Ansible playbook commands against s3 bucket

    cleanup(bucket, role, function)

def deps():
    os.system('sudo amazon-linux-extras install ansible2 -y')
    os.system('sudo amazon-linux-extras install awscli -y')
    os.system('sudo amazon-linux-extras install epel -y')
    os.system('sudo yum install s3fs-fuse -y')

def cleanup(bucket, role, function):
    creds = load_aws_ec2_role_iam_credentials(role)

    client = boto3.client(
        service_name='lambda',
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['Token']
    )
    response = client.invoke(
        FunctionName=function,
        InvocationType='Event',
        LogType='None',
        Payload=get_cleanup_payload().encode(),
    )
    
    if response.StatusCode >= 200 and response.StatusCode <= 300:
        return

    raise "failed to invoke cleanup lambda"

def get_cleanup_payload(metadata_url_base=EC2_METADATA_URL_BASE):
    r = requests.get('{base}/latest/dynamic/instance-identity/document'.format(
        base=metadata_url_base,
    ))
    response_json = r.json()

    payload = {
        "method": "cleanup",
        "instance_id": response_json.get('instanceId')
    }

    return json.dumps(payload)

def load_aws_ec2_role_iam_credentials(role_name, metadata_url_base=EC2_METADATA_URL_BASE):
    """
    Requests an ec2 instance's IAM security credentials from the EC2 metadata service.
    :param role_name: Name of the instance's role.
    :param metadata_url_base: IP address for the EC2 metadata service.
    :return: dict, unmarshalled JSON response of the instance's security credentials
    """
    metadata_pkcs7_url = '{base}/latest/meta-data/iam/security-credentials/{role}'.format(
        base=metadata_url_base,
        role=role_name,
    )
    logger.debug("load_aws_ec2_role_iam_credentials connecting to %s" % metadata_pkcs7_url)
    response = requests.get(url=metadata_pkcs7_url)
    response.raise_for_status()
    security_credentials = response.json()
    return security_credentials


if __name__ == "__main__":
    main()