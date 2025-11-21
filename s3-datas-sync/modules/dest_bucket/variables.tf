variable "dest_bucket_name" {
  type = string
}

variable "dest_region" {
  type = string
}

variable "dest_profile" {
  type = string
}

variable "allow_replication_account_id" {
  type = string
}

variable "source_bucket_arn" {
  description = "ARN of the source S3 bucket (in source account)"
  type        = string
}

variable "source_account_id" {
  type        = string
  description = "AWS Account ID of the source account"
}

variable "dest_replication_role_name" {
  type        = string
  description = "IAM role name for S3 replication from destination to source"
}

variable "dest_replication_rule_id" {
  type        = string
  description = "Rule ID for S3 replication from destination to source"
}