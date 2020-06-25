# GRACE Ansible Lambda [![GoDoc](https://godoc.org/github.com/GSA/grace-ansible-lambda?status.svg)](https://godoc.org/github.com/GSA/grace-ansible-lambda) [![Go Report Card](https://goreportcard.com/badge/gojp/goreportcard)](https://goreportcard.com/report/github.com/GSA/grace-ansible-lambda)

**Lint Checks/Unit Tests:** [![CircleCI](https://circleci.com/gh/GSA/grace-ansible-lambda.svg?style=shield)](https://circleci.com/gh/GSA/grace-ansible-lambda)

The grace-ansible-lambda is a project to implement a decentralized methodology for execution of Ansible within a particular AWS account. The intent is to allow Ansible to execute as necessary on an interval for configuration management without needing to host a large infrastructure deployment.

The project uses a lambda function to coordinate the deployment and cleanup of a singular EC2 instance for executing Ansible against the known hosts within the AWS account. The EC2 is then responsible for calling the lambda function to initiate the cleanup action.

## Repository contents

- **./**: Terraform module to deploy and configure Lambda function, S3 Bucket and IAM roles and policies
- **lambda**: Go code for Lambda function

## Terraform Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| project | The project name used as a prefix for all resources | string | `"grace"` | no |
| appenv | The targeted application environment used in resource names | string | `"development"` | no |
| region | The AWS region for executing the EC2 | string | `"us-east-1"` | no |
| image_id | The Amazon Machine Image ID to use for the EC2 | string | `""` | no |
| instance_type | The instance type to use for the EC2 | string | `"t2.micro"` | no |
| keypair_name | The keypair name to use for the EC2 | string | `""` | no |
| subnet_id | The VPC Subnet ID where the EC2 should be placed | string | `""` | no |
| security_group_ids | A comma delimited list of security group ids | string | `""` | no |
| schedule_expression | Expression is used to adjust the trigger rate of the lambda function | string | `"rate(60 minutes)"` | no |

[top](#top)

## Environment Variables

### Lambda Environment Variables

| Name                 | Description |
| -------------------- | ------------|
| REGION               | (optional) Region used for EC2 instances (default: us-east-1) |
| IMAGE_ID             | (optional) Region used for EC2 instances (default: us-east-1) |
| INSTANCE_TYPE        | (optional) Specifies the instance type for the EC2 (e.g. t2.micro) |
| KEYPAIR_NAME         | (optional) The key pair name to use for the EC2 |
| PROFILE_ARN          | (optional) IAM Instance Profile Arn for the EC2 |
| SUBNET_ID            | (optional) The subnet ID where the EC2 should be created |
| SECURITY_GROUP_IDS   | (optional) A comma delimited list of Security Group IDs |

[top](#top)

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.