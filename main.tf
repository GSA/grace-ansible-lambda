
data "aws_caller_identity" "current" {}

locals {
  app_name       = "${var.project}-${var.appenv}-ansible-lambda"
  account_id     = data.aws_caller_identity.current.account_id
  lambda_src     = "release/grace-ansible-lambda.zip"
  lambda_handler = "grace-ansible-lambda"
}