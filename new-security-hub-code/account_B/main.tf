provider "aws" {
  region  = var.region
  profile = var.account_b_profile
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_b_profile" {
  type    = string
  default = "source"
}
variable "account_a_id" {
  type    = string
  default = "473278020383"
}
variable "bucket_name" {
  type    = string
  default = "securityhub-export-bucket-12345" # change to globally unique name
}
variable "sns_email" {
  type    = string
  default = "ashwini.kanagaraj@digidense.in"
}
variable "lambda_function_name" {
  type    = string
  default = "export-securityhub-findings"
}

data "aws_caller_identity" "current" {}

# S3 bucket for CSV exports
resource "aws_s3_bucket" "securityhub_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

# S3 Bucket Policy - allows Security Hub exports, Lambda writes, and Account A cross-account writes
resource "aws_s3_bucket_policy" "securityhub_bucket_policy" {
  bucket = aws_s3_bucket.securityhub_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSecurityHubExports"
        Effect    = "Allow"
        Principal = { Service = "securityhub.amazonaws.com" }
        Action    = ["s3:PutObject", "s3:GetObject"]
        Resource  = "${aws_s3_bucket.securityhub_bucket.arn}/*"
      },
      {
        Sid       = "AllowLambdaWrite"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.lambda_role.arn }
        Action    = ["s3:PutObject", "s3:GetObject"]
        Resource  = "${aws_s3_bucket.securityhub_bucket.arn}/*"
      },
      {
        Sid       = "AllowAccountAWrite"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" }
        Action    = ["s3:PutObject", "s3:GetObject"]
        Resource  = "${aws_s3_bucket.securityhub_bucket.arn}/*"
      }
    ]
  })
}


data "aws_iam_policy_document" "policy" {
  statement {
    sid    = "SecurityHubFullRead"
    effect = "Allow"
    actions = [
      "securityhub:GetFindings",
      "securityhub:DescribeHub",
      "securityhub:GetEnabledStandards",
      "securityhub:BatchImportFindings",
      "securityhub:ListMembers",
      "securityhub:ListFindings"
    ]
    resources = [
      "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:hub/default",
      "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:product/*/*",
      "arn:aws:securityhub:${var.region}:${data.aws_caller_identity.current.account_id}:finding/*/*/*"
    ]
  }

  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = ["${aws_s3_bucket.securityhub_bucket.arn}/*"]
  }

  statement {
    sid      = "SNSPublish"
    effect   = "Allow"
    actions  = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket                  = aws_s3_bucket.securityhub_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Allow Account A to put objects (optional - useful if Account A might write directly)
resource "aws_s3_bucket_policy" "cross_write" {
  bucket = aws_s3_bucket.securityhub_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" },
        Action = ["s3:PutObject","s3:GetObject"],
        Resource = "${aws_s3_bucket.securityhub_bucket.arn}/*"
      }
    ]
  })
}

# SNS topic for alerts (you said email notifications already working)
resource "aws_sns_topic" "alerts" {
  name = "securityhub-alert-topic"
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# Lambda role and policy (Lambda will convert JSON -> CSV and put to S3)
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


# Package Lambda code (expects a local ./lambda directory with handler.py)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/handler.zip"
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


# Custom Event Bus that receives forwarded events from Account A
resource "aws_cloudwatch_event_bus" "forward_bus" {
  name = "securityhub-forwarding"
}

# Allow Account A to put events into this bus (principal must be account root or role)
resource "aws_cloudwatch_event_bus_policy" "allow_account_a" {
  event_bus_name = aws_cloudwatch_event_bus.forward_bus.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAccountAEvents",
        Effect = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" },
        Action   = "events:PutEvents",
        Resource = aws_cloudwatch_event_bus.forward_bus.arn
      }
    ]
  })
}

# Role that Account A's forwarder can assume (optional, helps with cross-account invocation)
resource "aws_iam_role" "eventbridge_target_role" {
  name = "EventBridgeCrossAccountInvokeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Allow the role to invoke Lambda
resource "aws_iam_role_policy" "eventbridge_target_policy" {
  role = aws_iam_role.eventbridge_target_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = aws_lambda_function.exporter.arn }
    ]
  })
}

# Event rule on the custom bus that triggers Lambda when SecurityHub events arrive
resource "aws_cloudwatch_event_rule" "process_securityhub_events" {
  name           = "process-securityhub-events"
  event_bus_name = aws_cloudwatch_event_bus.forward_bus.name
  description    = "Process forwarded SecurityHub events from Account A"

  event_pattern = jsonencode({
    source = ["aws.securityhub"]
  })
}

# Event target: custom bus rule invokes Lambda
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule           = aws_cloudwatch_event_rule.process_securityhub_events.name
  event_bus_name = aws_cloudwatch_event_rule.process_securityhub_events.event_bus_name
  arn            = aws_lambda_function.exporter.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.exporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_securityhub_events.arn
}

# Outputs
output "central_lambda_arn" {
  value = aws_lambda_function.exporter.arn
}

output "central_bucket_arn" {
  value = aws_s3_bucket.securityhub_bucket.arn
}

output "account_b_event_bus_arn" {
  value = aws_cloudwatch_event_bus.forward_bus.arn
}
