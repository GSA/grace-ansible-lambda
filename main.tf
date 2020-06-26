
data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnet_ids" "vpc" {
  vpc_id = var.vpc_id
}

locals {
  app_name       = "${var.project}-${var.appenv}-ansible-lambda"
  account_id     = data.aws_caller_identity.current.account_id
  lambda_handler = "grace-ansible-lambda"
}