terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.dest, aws.source]
    }
  }
}

# DEST BUCKET (Account B)
resource "aws_s3_bucket" "bucket02-aurorat" {
  provider = aws.dest
  bucket   = var.dest_bucket_name
}

resource "aws_s3_bucket_versioning" "versioning" {
  provider = aws.dest
  bucket   = aws_s3_bucket.bucket02-aurorat.id

  versioning_configuration {
    status = "Enabled"
  }
}


# Allow SOURCE account to replicate INTO DEST bucket
data "aws_iam_policy_document" "dest_bucket_policy" {
  statement {
    sid = "AllowReplicationFromSource"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.allow_replication_account_id}:root"]
    }

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging"
    ]

    resources = [
      aws_s3_bucket.bucket02-aurorat.arn,
      "${aws_s3_bucket.bucket02-aurorat.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "dest_policy" {
  provider = aws.dest
  bucket   = aws_s3_bucket.bucket02-aurorat.id
  policy   = data.aws_iam_policy_document.dest_bucket_policy.json
}

#############################################
# DEST REPLICATION ROLE + POLICY (B → A)
#############################################

# Trust policy for S3 to assume this role
data "aws_iam_policy_document" "dest_replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dest_replication_role" {
  provider           = aws.dest
  name               = var.dest_replication_role_name   # now v2
  assume_role_policy = data.aws_iam_policy_document.dest_replication_assume.json
}

data "aws_iam_policy_document" "dest_replication_role_policy" {

  # Read from DEST bucket (this bucket)
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.bucket02-aurorat.arn
    ]
  }

  # Read object versions from DEST bucket
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
      "${aws_s3_bucket.bucket02-aurorat.arn}/*"
    ]
  }

  # Write into SOURCE bucket (reverse direction)
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]
    resources = [
      "${var.source_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "dest_replication_role_policy_attach" {
  provider = aws.dest
  name     = "${var.dest_replication_role_name}-policy"
  role     = aws_iam_role.dest_replication_role.id
  policy   = data.aws_iam_policy_document.dest_replication_role_policy.json
}

#############################################
# DEST → SOURCE REPLICATION RULE
#############################################

resource "aws_s3_bucket_replication_configuration" "dest_to_source_replication" {
  provider = aws.dest
  bucket   = aws_s3_bucket.bucket02-aurorat.id

  role = aws_iam_role.dest_replication_role.arn

  rule {
    id     = var.dest_replication_rule_id
    status = "Enabled"

    filter {
      prefix = ""
    }

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = var.source_bucket_arn   # ARN of source bucket
      account       = var.source_account_id   # source account id
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.versioning,
    aws_iam_role_policy.dest_replication_role_policy_attach
  ]
}
