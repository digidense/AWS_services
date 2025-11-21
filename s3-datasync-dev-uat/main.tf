terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

########################################
# Providers – Dev & UAT accounts
########################################

provider "aws" {
  alias   = "dev"
  region  = var.region
  profile = var.dev_profile
}

provider "aws" {
  alias   = "uat"
  region  = var.region
  profile = var.uat_profile
}

########################################
# Optional: S3 buckets
########################################

resource "aws_s3_bucket" "dev_bucket" {
  provider = aws.dev
  bucket   = var.dev_bucket_name
}

resource "aws_s3_bucket" "uat_bucket" {
  provider = aws.uat
  bucket   = var.uat_bucket_name
}

########################################
# IAM Role for DataSync in UAT
########################################

resource "aws_iam_role" "datasync_role_uat" {
  provider = aws.uat
  name     = "datasync-s3-role-uat"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "datasync_role_policy_uat" {
  provider = aws.uat
  role     = aws_iam_role.datasync_role_uat.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 read/write permissions
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.dev_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.dev_bucket_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.uat_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:DeleteObjectVersion"]
        Resource = "arn:aws:s3:::${var.uat_bucket_name}/*"
      },
      # CloudWatch logs for DataSync
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/datasync/dev-to-uat:*"
      }
    ]
  })
}

########################################
# Bucket policies (cross-account)
########################################

resource "aws_s3_bucket_policy" "dev_bucket_policy" {
  provider = aws.dev
  bucket   = var.dev_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowDataSyncFromUATReadDevBucket"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.datasync_role_uat.arn }
        Action    = ["s3:ListBucket"]
        Resource  = "arn:aws:s3:::${var.dev_bucket_name}"
      },
      {
        Sid       = "AllowDataSyncFromUATReadDevObjects"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.datasync_role_uat.arn }
        Action    = ["s3:GetObject"]
        Resource  = "arn:aws:s3:::${var.dev_bucket_name}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "uat_bucket_policy" {
  provider = aws.uat
  bucket   = var.uat_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowDataSyncFromUATAccessUATBucket"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.datasync_role_uat.arn }
        Action    = ["s3:ListBucket"]
        Resource  = "arn:aws:s3:::${var.uat_bucket_name}"
      },
      {
        Sid       = "AllowDataSyncFromUATAccessUATObjects"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.datasync_role_uat.arn }
        Action    = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:DeleteObjectVersion"]
        Resource  = "arn:aws:s3:::${var.uat_bucket_name}/*"
      }
    ]
  })
}

########################################
# CloudWatch Log Group
########################################

resource "aws_cloudwatch_log_group" "datasync_log_group" {
  provider = aws.uat
  name     = "/aws/datasync/dev-to-uat"
}

########################################
# DataSync locations
########################################

resource "aws_datasync_location_s3" "dev" {
  provider      = aws.uat
  s3_bucket_arn = "arn:aws:s3:::${var.dev_bucket_name}"
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role_uat.arn
  }
}

resource "aws_datasync_location_s3" "uat" {
  provider      = aws.uat
  s3_bucket_arn = "arn:aws:s3:::${var.uat_bucket_name}"
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role_uat.arn
  }
}

########################################
# DataSync task
########################################

resource "aws_datasync_task" "dev_to_uat" {
  provider = aws.uat

  name                     = "dev-to-uat-model-sync"
  source_location_arn      = aws_datasync_location_s3.dev.arn
  destination_location_arn = aws_datasync_location_s3.uat.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_log_group.arn

  options {
    overwrite_mode         = "ALWAYS"
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    preserve_deleted_files = "PRESERVE"
    transfer_mode          = "CHANGED"
    log_level              = "BASIC"

    posix_permissions = "NONE"
    uid               = "NONE"
    gid               = "NONE"
    atime             = "NONE"
    mtime             = "NONE"
  }
}

########################################
# Lambda to trigger DataSync task using index.zip
########################################

resource "aws_iam_role" "lambda_datasync_trigger_role" {
  provider = aws.uat
  name     = "lambda-datasync-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_datasync_trigger_policy" {
  provider = aws.uat
  role     = aws_iam_role.lambda_datasync_trigger_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["datasync:StartTaskExecution"],
        Resource = aws_datasync_task.dev_to_uat.arn
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "trigger_datasync" {
  provider      = aws.uat
  function_name = "trigger-datasync-task"
  role          = aws_iam_role.lambda_datasync_trigger_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  filename      = "index.zip"

  environment {
    variables = {
      DATASYNC_TASK_ARN = aws_datasync_task.dev_to_uat.arn
      # AWS_REGION removed
    }
  }
}
