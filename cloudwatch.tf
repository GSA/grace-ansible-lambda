resource "aws_cloudwatch_event_rule" "schedule" {
  name                = local.app_name
  description         = "Triggers the execution of the ${local.app_name}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "schedule" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = local.app_name
  arn       = aws_lambda_function.lambda.arn
}

resource "aws_cloudwatch_log_group" "ansible" {
  name = "/aws/events/ansible"
}