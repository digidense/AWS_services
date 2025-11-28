resource "aws_sns_topic" "findings_topic" {
  name = "securityhub-findings"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.findings_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email
}
