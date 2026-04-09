# COST OPTIMIZATION: CloudWatch log retention
# Default CloudWatch log groups never expire — logs accumulate indefinitely
# At $0.50/GB ingested + $0.03/GB stored, unmanaged retention is a silent cost sink

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.retention_in_days

  tags = var.tags
}
