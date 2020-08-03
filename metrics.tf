resource "aws_cloudwatch_log_metric_filter" "all_changes" {
  name           = "all_changes"
  pattern        = "{$.detail-type = ansible-run-report}"
  log_group_name = aws_cloudwatch_log_group.ansible.name

  metric_transformation {
    name          = "all_changes"
    namespace     = "Ansible"
    value         = "$.detail.stats.changed"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "all_failed" {
  name           = "all_failed"
  pattern        = "{$.detail-type = ansible-run-report}"
  log_group_name = aws_cloudwatch_log_group.ansible.name

  metric_transformation {
    name          = "all_failed"
    namespace     = "Ansible"
    value         = "$.detail.stats.failed"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "all_ok" {
  name           = "all_ok"
  pattern        = "{$.detail-type = ansible-run-report}"
  log_group_name = aws_cloudwatch_log_group.ansible.name

  metric_transformation {
    name          = "all_ok"
    namespace     = "Ansible"
    value         = "$.detail.stats.ok"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "all_skipped" {
  name           = "all_skipped"
  pattern        = "{$.detail-type = ansible-run-report}"
  log_group_name = aws_cloudwatch_log_group.ansible.name

  metric_transformation {
    name          = "all_skipped"
    namespace     = "Ansible"
    value         = "$.detail.stats.skipped"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "all_unreachable" {
  name           = "all_unreachable"
  pattern        = "{($.detail-type = ansible-run-report) && ($.detail.unreachable == true)}"
  log_group_name = aws_cloudwatch_log_group.ansible.name

  metric_transformation {
    name          = "all_unreachable"
    namespace     = "Ansible"
    value         = "1"
    default_value = "0"
  }
}