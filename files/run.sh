#!/bin/sh

outputFile="/tmp/grace-ansible-runner.zip"
binaryFile="/tmp/grace-ansible-runner"
amzFile="files/grace-ansible-runner.zip"
resource="/${bucket}/$${amzFile}"
contentType="application/zip"
dateValue=`TZ=GMT date -R`
stringToSign="GET\n\n$${contentType}\n$${dateValue}\n$${resource}"
credRegex="AccessKeyId\W+((?<![A-Z0-9])[A-Z0-9]{20}(?![A-Z0-9]))\W+SecretAccessKey\W+((?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=]))\W+Token\W+((?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{275,300}(?![A-Za-z0-9/+=]))"

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
CRED=`curl -H "X-aws-ec2-metadata-token: $$TOKEN" -v "http://169.254.169.254/latest/meta-data/iam/security-credentials/${role}"`
if [[ $$CRED =~ $$credRegex ]]; then
    s3Key="$${BASH_REMATCH[1]}"
    s3Secret="$${BASH_REMATCH[2]}"
    signature=`echo -en $${stringToSign} | openssl sha1 -hmac $${s3Secret} -binary | base64`
    curl -H "Host: s3-${region}.amazonaws.com" \
        -H "Date: $${dateValue}" \
        -H "Content-Type: $${contentType}" \
        -H "Authorization: AWS $${s3Key}:$${signature}" \
        https://s3-${region}.amazonaws.com/${bucket}/$${amzFile} -o $$outputFile
else
    echo "failed to parse $$CRED"
    exit 1
fi

export REGION="${region}"
export BUCKET="${bucket}"
export FUNC_NAME="${function}"
export HOSTS_FILE="${hosts_file}"
export SITE_FILE="${site_file}"

sudo yum -y install unzip

cd /tmp
unzip $$outputFile .

chmod +x $$binaryFile
$$binaryFile