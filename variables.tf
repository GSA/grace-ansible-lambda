variable "project" {
  type        = string
  description = "(optional) The project name used as a prefix for all resources"
  default     = "grace"
}

variable "appenv" {
  type        = string
  description = "(optional) The targeted application environment used in resource names (default: development)"
  default     = "development"
}

variable "region" {
  type        = string
  description = "(optional) The AWS region for executing the EC2 (default: us-east-1)"
  default     = "us-east-1"
}

variable "image_id" {
  type        = string
  description = "(optional) The Amazon Machine Image ID to use for the EC2"
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "(optional) The instance type to use for the EC2 (default: t2.micro)"
  default     = "t2.micro"
}

variable "profile_arn" {
  type        = string
  description = "(optional) The IAM Instance Profile Arn to use for the EC2"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "(optional) The VPC Subnet ID where the EC2 should be placed"
  default     = ""
}

variable "security_group_ids" {
  type        = string
  description = "(optional) A comma delimited list of security group ids"
  default     = ""
}

variable "schedule_expression" {
  type        = string
  description = "(optional) Expression is used to adjust the trigger rate of the lambda function (default: rate(60 minutes))"
  default     = "rate(60 minutes)"
}

# TODO: uncomment when aws_iam_policy_document.kms supports dynamic updates
# 
# variable "config_role_arn" {
#     type = string
#     description = "(optional) The Role Arn used by the AWS Config service"
#     value = ""
# }