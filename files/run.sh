#!/bin/sh 
outputFile="/tmp/grace-ansible-runner"
amzFile="files/grace-ansible-runner.zip"
region="${region}"
bucket="${bucket}"
resource="/${bucket}/${amzFile}"
contentType="binary/octet-stream"
dateValue=`TZ=GMT date -R`
# You can leave our "TZ=GMT" if your system is already GMT (but don't have to)
stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
s3Key="ACCESS_KEY_ID"
s3Secret="SECRET_ACCESS_KEY"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
curl -H "Host: s3-${region}.amazonaws.com" \
     -H "Date: ${dateValue}" \
     -H "Content-Type: ${contentType}" \
     -H "Authorization: AWS ${s3Key}:${signature}" \
     https://s3-${region}.amazonaws.com/${bucket}/${amzFile} -o $outputFile

