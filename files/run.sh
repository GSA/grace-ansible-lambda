#!/bin/bash

sudo yum -y install jq
sudo yum -y install unzip

outputFile="/tmp/grace-ansible-runner.zip"
binaryFile="/tmp/grace-ansible-runner"
amzFile="files/grace-ansible-runner.zip"
resource="/${bucket}/$${amzFile}"
contentType="application/zip"
dateValue=`TZ=GMT date -R`
stringToSign="GET\n\n$${contentType}\n$${dateValue}\n$${resource}"
credRegex="AccessKeyId\W+((?<![A-Z0-9])[A-Z0-9]{20}(?![A-Z0-9]))\W+SecretAccessKey\W+((?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=]))\W+Token\W+((?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{975,1200}(?![A-Za-z0-9/+=]))"

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
CRED=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v "http://169.254.169.254/latest/meta-data/iam/security-credentials/${role}"`

awsKey=`echo $CRED | jq -r .AccessKeyId`
awsSecret=`echo $CRED | jq -r .SecretAccessKey`
awsToken=`echo $CRED | jq -r .Token`

signature=`echo -en $${stringToSign} | openssl sha1 -hmac $${awsSecret} -binary | base64`
curl -H "Host: s3-${region}.amazonaws.com" \
    -H "Date: $${dateValue}" \
    -H "Content-Type: $${contentType}" \
    -H "Authorization: AWS $${awsKey}:$${signature}" \
    https://s3.${region}.amazonaws.com/${bucket}/$${amzFile} -o $outputFile


export REGION="${region}"
export BUCKET="${bucket}"
export FUNC_NAME="${function}"
export HOSTS_FILE="${hosts_file}"
export SITE_FILE="${site_file}"

cd /tmp
unzip $outputFile
chmod +x $binaryFile
$binaryFile