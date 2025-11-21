############################################################
# TERRAFORM & PROVIDERS
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------
# SOURCE ACCOUNT PROVIDER  (Account A)
# -----------------------------------------
provider "aws" {
  alias   = "source"
  region  = var.source_region
  profile = var.source_profile
}

# -----------------------------------------
# DESTINATION ACCOUNT PROVIDER (Account B)
# -----------------------------------------
provider "aws" {
  alias   = "dest"
  region  = var.dest_region
  profile = var.dest_profile
}

############################################################
# DESTINATION BUCKET CREATION  (Account B)
############################################################

module "dest_bucket" {
  source = "./modules/dest_bucket"

  providers = {
    aws.dest   = aws.dest
    aws.source = aws.source
  }

  dest_bucket_name             = var.dest_bucket_name
  dest_region                  = var.dest_region
  dest_profile                 = var.dest_profile

  # Who is allowed to replicate *into* this dest bucket
  allow_replication_account_id = var.source_account_id

  # For reverse replication (B -> A)
  source_bucket_arn            = "arn:aws:s3:::${var.source_bucket_name}"
  source_account_id            = var.source_account_id

  # 👇 NEW UNIQUE ROLE NAME (changed)
  dest_replication_role_name   = "dest-to-source-repl-role-v2"
  dest_replication_rule_id     = "dest-to-source-repl"
}

############################################################
# SOURCE REPLICATION SETUP (Account A)
############################################################

module "source_replication" {
  source = "./modules/source_replication"

  providers = {
    aws.source = aws.source
    aws.dest   = aws.dest
  }

  source_bucket_name      = var.source_bucket_name
  source_region           = var.source_region
  source_profile          = var.source_profile

  # Role for source -> dest (A -> B)
  replication_role_name   = "s3-replication-role"
  replication_rule_id     = "replicate-all"

  dest_bucket_arn         = module.dest_bucket.dest_bucket_arn
  dest_account_id         = var.dest_account_id

  replicate_delete_marker = false

  # 🔹 Values needed only for bucket policy (allow B -> A)
  source_bucket_arn          = "arn:aws:s3:::${var.source_bucket_name}"
  source_account_id          = var.source_account_id

  # These are NOT used to create a role in source module anymore,
  # just keep them if your variables require them or remove them if unused.
  dest_replication_rule_id   = "dest-to-source-repl"
  dest_replication_role_name = "dest-to-source-repl-role-v2"
}
