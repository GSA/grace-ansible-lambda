#!/usr/bin/python3

import os
import boto3
import yaml
import json
import urllib.request

def create_secrets_yaml(path):
    secrets = get_secrets_dict()
    f = open(path, 'w')
    yaml.dump(secrets, f)

secret_prefix = 'ansible-'

def is_match(secret):
    return secret['Name'].startswith(secret_prefix)

def get_secrets_dict():
    secret_ids = list_secrets(is_match)
    secrets = get_secret_dict(secret_ids)
    return secrets

def is_json(str):
    chars = {
        34: True,
        91: True,
        123: True,
    }
    return chars.get(ord(str[0]), False)

def get_secret_dict(secret_ids):
    client: botostubs.SecretsManager = boto3.client('secretsmanager')

    secrets = {}
    for id in secret_ids:
        result = client.get_secret_value(SecretId=id)
        name = result['Name'][len(secret_prefix):]
        value = result['SecretString']
        if is_json(value):
            secrets[name] = json.loads(value)
        else:
            secrets[name] = value
    return secrets

def list_secrets(matcher):
    client: botostubs.SecretsManager = boto3.client('secretsmanager')

    token = ''
    secret_ids = []

    while token is not None:
        if len(token) > 0:
            result = client.list_secrets(NextToken=token)
        else:
            result = client.list_secrets()
        secret_ids.extend(
            get_secret_ids(result['SecretList'], matcher)
        )
        token = result.get('NextToken', None)
    return secret_ids

def get_secret_ids(secrets, matcher):
    secret_ids = []
    for s in secrets:
        if matcher(s):
            secret_ids.append(
                s['ARN']
                #list(s['SecretVersionsToStages'].keys())[0]
            )
    return secret_ids

if __name__ == '__main__':
    print('creating secrets.yaml')
    create_secrets_yaml('/tmp/ansible/secrets.yaml')

    os.system('sudo yum -y install awscli')
    os.system('amazon-linux-extras install ansible2 -y')
    os.system('cd /tmp')
    os.system('aws s3 cp --region ${region} --recursive s3://${bucket}/ .')
    os.system('aws s3 cp --region ${region} s3://${bucket}/files/id_rsa ${key_file}')
    os.system('chown 400 ${key_file}')
    os.system('ansible-playbook --private-key ${key_file} -u ${ec2_user} -i ${hosts_file} ${site_file}')

    instance_id = urllib.request.urlopen('http://169.254.169.254/latest/meta-data/instance-id').read().decode()

    os.system('aws s3 cp --region ${region} /var/log/cloud-init-output.log "s3://${bucket}/logs/run-' + instance_id + '.log")
    os.system('aws ec2 terminate-instances --region ${region} --instance-ids ' + instance_id)