provider "aws" {
  region  = var.region
  profile = var.account_a_profile
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_a_profile" {
  type    = string
  default = "dest"
}
variable "account_b_id" {
  type    = string
  default = "165220828225"
}
variable "account_b_event_bus_arn" {
  type    = string
  default = "arn:aws:events:us-east-1:165220828225:event-bus/securityhub-forwarding"
}

# Role in Account A that EventBridge (events.amazonaws.com) will assume to forward to Account B.
resource "aws_iam_role" "eventbridge_forward_role" {
  name = "EventBridgeForwardRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action  = "sts:AssumeRole"
      }
    ]
  })
}

# This policy allows the role to assume the role in Account B (target role).
resource "aws_iam_role_policy" "forward_policy" {
  name = "ForwardToAccountBPolicy"
  role = aws_iam_role.eventbridge_forward_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Resource = "arn:aws:iam::${var.account_b_id}:role/EventBridgeCrossAccountInvokeRole"
      }
    ]
  })
}

# Event rule in Account A capturing SecurityHub events
resource "aws_cloudwatch_event_rule" "forward_securityhub" {
  name           = "forward-securityhub"
  description    = "Forward SecurityHub events to Account B"
  event_bus_name = "default"

  event_pattern = <<EOF
{
  "source": ["aws.securityhub"]
}
EOF
}

# Event target sends to Account B event bus using the local role (aws_iam_role.eventbridge_forward_role)
resource "aws_cloudwatch_event_target" "to_account_b" {
  rule     = aws_cloudwatch_event_rule.forward_securityhub.name
  arn      = var.account_b_event_bus_arn
  role_arn = aws_iam_role.eventbridge_forward_role.arn
}

# Allow EventBridgeForwardRole to get SecurityHub findings in Account B
resource "aws_iam_role_policy" "securityhub_get_findings" {
  name = "SecurityHubGetFindingsPolicy"
  role = aws_iam_role.eventbridge_forward_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "securityhub:GetFindings",
        Resource = "*"
      }
    ]
  })
}
