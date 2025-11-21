terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.dest, aws.source]
    }
  }
}

# SOURCE BUCKET (Account A)
resource "aws_s3_bucket" "bucket-sample-8124" {
  provider = aws.source
  bucket   = var.source_bucket_name
}

resource "aws_s3_bucket_versioning" "versioning" {
  provider = aws.source
  bucket   = aws_s3_bucket.bucket-sample-8124.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Assume role policy for replication role in SOURCE account (A → B)
data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication_role" {
  provider           = aws.source
  name               = var.replication_role_name
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication_role_policy" {

  # Source bucket read permissions
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.bucket-sample-8124.arn
    ]
  }

  # Source bucket object read permissions
  statement {
    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectLegalHold",
      "s3:GetObjectRetention",
      "s3:GetObjectVersionTorrent"
    ]
    resources = [
      "${aws_s3_bucket.bucket-sample-8124.arn}/*"
    ]
  }

  # Destination bucket write permissions (A → B)
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]
    resources = [
      "${var.dest_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "replication_role_policy_attach" {
  provider = aws.source
  name     = "${var.replication_role_name}-policy"
  role     = aws_iam_role.replication_role.id
  policy   = data.aws_iam_policy_document.replication_role_policy.json
}

# SOURCE → DEST replication rule
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.source
  bucket   = aws_s3_bucket.bucket-sample-8124.id

  role = aws_iam_role.replication_role.arn

  rule {
    id     = var.replication_rule_id
    status = "Enabled"

    filter {
      prefix = ""
    }

    # 🔥 Required for new AWS Replication Schema
    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = var.dest_bucket_arn
      account       = var.dest_account_id
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.versioning,
    aws_iam_role_policy.replication_role_policy_attach
  ]
}

#############################################
# SOURCE BUCKET POLICY (allow DEST → SOURCE)
#############################################

data "aws_iam_policy_document" "source_bucket_policy" {
  statement {
    sid = "AllowReplicationFromDestination"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.dest_account_id}:root"]
    }

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging"
    ]

    resources = [
      aws_s3_bucket.bucket-sample-8124.arn,
      "${aws_s3_bucket.bucket-sample-8124.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "source_policy" {
  provider = aws.source
  bucket   = aws_s3_bucket.bucket-sample-8124.id
  policy   = data.aws_iam_policy_document.source_bucket_policy.json
}
