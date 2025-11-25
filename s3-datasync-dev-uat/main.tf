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
# Providers – DEV & UAT
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
# Buckets
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
# IAM Role - DataSync (UAT) – used for S3 access
########################################

resource "aws_iam_role" "datasync_role_uat" {
  provider = aws.uat
  name     = "datasync-cross-account-role-uat"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "datasync.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

########################################
# IAM Role Policy (UAT → DEV)
########################################
# UAT bucket = SOURCE (READ)
# DEV bucket = DESTINATION (WRITE)
########################################

resource "aws_iam_role_policy" "datasync_role_policy_uat" {
  provider = aws.uat
  role     = aws_iam_role.datasync_role_uat.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      # ---- UAT bucket: READ ONLY (Source) ----
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:aws:s3:::${var.uat_bucket_name}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging"
        ],
        Resource = "arn:aws:s3:::${var.uat_bucket_name}/*"
      },

      # ---- DEV bucket: READ/WRITE (Destination) ----
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:aws:s3:::${var.dev_bucket_name}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::${var.dev_bucket_name}/*"
      },

      # ---- CloudWatch Logs ----
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

########################################
# DEV Bucket Policy – allow UAT DataSync to WRITE
########################################

resource "aws_s3_bucket_policy" "dev_bucket_policy" {
  provider = aws.dev
  bucket   = var.dev_bucket_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      # Allow UAT role to write into DEV bucket
      {
        Sid    = "AllowUATDataSyncAccessWrite",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.uat_account_id}:role/datasync-cross-account-role-uat"
        },
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObjectTagging",
          "s3:DeleteObject",
          "s3:GetObject"
        ],
        Resource = "arn:aws:s3:::${var.dev_bucket_name}/*"
      },

      # Allow listing DEV bucket
      {
        Sid    = "AllowUATDataSyncListBucket",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.uat_account_id}:role/datasync-cross-account-role-uat"
        },
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:aws:s3:::${var.dev_bucket_name}"
      }
    ]
  })
}

########################################
# DataSync Locations (Reversed: UAT → DEV)
########################################

# SOURCE = UAT
resource "aws_datasync_location_s3" "source_uat" {
  provider      = aws.uat
  s3_bucket_arn = "arn:aws:s3:::${var.uat_bucket_name}"
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role_uat.arn
  }
}

# DESTINATION = DEV
resource "aws_datasync_location_s3" "dest_dev" {
  provider      = aws.uat
  s3_bucket_arn = "arn:aws:s3:::${var.dev_bucket_name}"
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role_uat.arn
  }
}

########################################
# CloudWatch Log Group
########################################

resource "aws_cloudwatch_log_group" "datasync_log_group" {
  provider          = aws.uat
  name              = "/aws/datasync/uat-to-dev"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_resource_policy" "datasync_logs_policy" {
  provider    = aws.uat
  policy_name = "datasync-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowDataSyncServiceToWriteLogs",
        Effect = "Allow",
        Principal = {
          Service = "datasync.amazonaws.com"
        },
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = [
          aws_cloudwatch_log_group.datasync_log_group.arn,
          "${aws_cloudwatch_log_group.datasync_log_group.arn}:*"
        ]
      }
    ]
  })
}

########################################
# DataSync Task (UAT → DEV)
########################################

resource "aws_datasync_task" "uat_to_dev" {
  provider = aws.uat

  name                     = "uat-to-dev-model-sync"
  source_location_arn      = aws_datasync_location_s3.source_uat.arn
  destination_location_arn = aws_datasync_location_s3.dest_dev.arn

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync_log_group.arn

  depends_on = [
    aws_cloudwatch_log_resource_policy.datasync_logs_policy
  ]

  options {
    overwrite_mode = "ALWAYS"
    transfer_mode  = "CHANGED"
    verify_mode    = "POINT_IN_TIME_CONSISTENT"
    log_level      = "BASIC"

    posix_permissions = "NONE"
    uid               = "NONE"
    gid               = "NONE"
    atime             = "NONE"
    mtime             = "NONE"
  }
}

