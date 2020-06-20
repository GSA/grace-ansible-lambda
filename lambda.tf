resource "aws_lambda_function" "lambda" {
  filename                       = local.lambda_src
  function_name                  = local.app_name
  description                    = "Creates an EC2 instance and executes Ansible playbooks"
  role                           = aws_iam_role.role.arn
  handler                        = var.lambda_handler
  source_code_hash               = filesha256(var.lambda_src)
  kms_key_arn                    = aws_kms_key.kms_key.arn
  reserved_concurrent_executions = 1
  runtime                        = "go1.x"
  timeout                        = 900

  environment {
    variables = {
      REGION             = var.region
      IMAGE_ID           = var.image_id
      INSTANCE_TYPE      = var.instance_type
      PROFILE_ARN        = var.profile_arn
      USERDATA_BUCKET    = aws_s3_bucket.bucket.id
      USERDATA_KEY       = "files/run.sh"
      SUBNET_ID          = var.subnet_id
      SECURITY_GROUP_IDS = var.security_group_ids
    }
  }
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