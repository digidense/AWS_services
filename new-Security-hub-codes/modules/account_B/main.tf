provider "aws" {
  region  = var.region
  profile = var.account_a_profile
}

resource "aws_iam_role" "eventbridge_forward_role" {
  name = "EventBridgeForwardRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "forward_policy" {
  name = "ForwardToAccountBPolicy"
  role = aws_iam_role.eventbridge_forward_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${var.account_b_id}:role/EventBridgeCrossAccountInvokeRole"
    }]
  })
}

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

resource "aws_cloudwatch_event_target" "to_account_b" {
  rule     = aws_cloudwatch_event_rule.forward_securityhub.name
  arn      = var.account_b_event_bus_arn
  role_arn = aws_iam_role.eventbridge_forward_role.arn
}

resource "aws_iam_role_policy" "securityhub_get_findings" {
  name = "SecurityHubGetFindingsPolicy"
  role = aws_iam_role.eventbridge_forward_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "securityhub:GetFindings",
      Resource = "*"
    }]
  })
}
