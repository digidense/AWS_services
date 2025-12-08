provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# S3 bucket
resource "aws_s3_bucket" "securityhub_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket                  = aws_s3_bucket.securityhub_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SNS topic
resource "aws_sns_topic" "alerts" {
  name = "securityhub-alert-topic"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# Lambda role
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "central-securityhub-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "central-securityhub-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "securityhub:GetFindings",
          "securityhub:DescribeHub",
          "securityhub:GetInsightResults",
          "securityhub:ListMembers"
        ],
        Resource = [
          "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:hub/default",
          "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:product/*/*",
          "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:finding/*/*/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:GetObject"],
        Resource = "${aws_s3_bucket.securityhub_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda"
  output_path = "${path.root}/handler.zip"
}

resource "aws_lambda_function" "exporter" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.securityhub_bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Custom Event Bus
resource "aws_cloudwatch_event_bus" "forward_bus" {
  name = "securityhub-forwarding"
}

resource "aws_cloudwatch_event_bus_policy" "allow_account_a" {
  event_bus_name = aws_cloudwatch_event_bus.forward_bus.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowAccountAEvents"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" }
        Action    = "events:PutEvents"
        Resource  = aws_cloudwatch_event_bus.forward_bus.arn
      }
    ]
  })
}

# Event rule to trigger Lambda
resource "aws_cloudwatch_event_rule" "process_securityhub_events" {
  name           = "process-securityhub-events"
  event_bus_name = aws_cloudwatch_event_bus.forward_bus.name
  description    = "Process forwarded SecurityHub events from Account A"

  event_pattern = jsonencode({
    source = ["aws.securityhub"]
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule           = aws_cloudwatch_event_rule.process_securityhub_events.name
  event_bus_name = aws_cloudwatch_event_rule.process_securityhub_events.event_bus_name
  arn            = aws_lambda_function.exporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.exporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_securityhub_events.arn
}
