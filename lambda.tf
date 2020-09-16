resource "aws_lambda_function" "lambda" {
  filename                       = var.source_file
  function_name                  = local.app_name
  description                    = "Creates an EC2 instance and executes Ansible playbooks"
  role                           = aws_iam_role.role.arn
  handler                        = local.lambda_handler
  source_code_hash               = filebase64sha256(var.source_file)
  kms_key_arn                    = aws_kms_key.kms.arn
  reserved_concurrent_executions = 1
  runtime                        = "go1.x"
  timeout                        = 900

  environment {
    variables = {
      REGION             = var.region
      IMAGE_ID           = var.image_id
      AMI_SEARCH_TERM    = var.ami_search_term
      AMI_OWNER_ALIAS    = var.ami_owner_alias
      INSTANCE_TYPE      = var.instance_type
      PROFILE_ARN        = aws_iam_instance_profile.profile.arn
      USERDATA_BUCKET    = aws_s3_bucket.bucket.id
      USERDATA_KEY       = aws_s3_bucket_object.user_data.key
      SUBNET_ID          = var.subnet_id
      SECURITY_GROUP_IDS = var.security_group_ids
      KEYPAIR_NAME       = var.keypair_name
      JOB_TIMEOUT_SECS   = var.job_timeout_secs
    }
  }

  depends_on = [aws_iam_role_policy_attachment.attach]
}

# used to trigger lambda when the bucket updates
resource "aws_lambda_permission" "bucket_invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# used to trigger lambda on a schedule
resource "aws_lambda_permission" "cloudwatch_invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

resource "aws_lambda_function" "rotate_keypair" {
  filename                       = var.rotate_keypair_source_file
  function_name                  = local.rotate_keypair_name
  description                    = "Rotates the ansible key pairs secret"
  role                           = aws_iam_role.role.arn
  handler                        = local.rotate_handler
  source_code_hash               = filebase64sha256(var.rotate_keypair_source_file)
  kms_key_arn                    = aws_kms_key.kms.arn
  reserved_concurrent_executions = 1
  runtime                        = "go1.x"
  timeout                        = 900

  environment {
    variables = {
      REGION       = var.region
      KEYPAIR_NAME = var.keypair_name
      SECRET_NAME  = var.secret_name
    }
  }

  depends_on = [aws_iam_role_policy_attachment.attach]
}
