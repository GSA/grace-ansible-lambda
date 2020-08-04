resource "aws_cloudwatch_event_rule" "ansible" {
  name        = "ansible_events"
  description = "matches all ansible related events"

  event_pattern = <<EOF
{
  "source": [
    "ansible"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "ansible" {
  rule = aws_cloudwatch_event_rule.ansible.name
  arn  = aws_cloudwatch_log_group.ansible.arn
}