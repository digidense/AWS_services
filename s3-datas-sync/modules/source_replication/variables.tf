variable "source_bucket_name" {
  type = string
}

variable "source_region" {
  type = string
}

variable "source_profile" {
  type = string
}

variable "replication_role_name" {
  type = string
}

variable "replication_rule_id" {
  type = string
}

variable "dest_bucket_arn" {
  type = string
}

variable "dest_account_id" {
  type = string
}

variable "replicate_delete_marker" {
  type    = bool
  default = false
}

variable "source_bucket_arn" {
  description = "ARN of the source S3 bucket (in source account)"
  type        = string
}

variable "source_account_id" {
  description = "AWS Account ID of the source account"
  type        = string
}

variable "dest_replication_role_name" {
  description = "IAM role name for S3 replication from destination to source"
  type        = string
}

variable "dest_replication_rule_id" {
  description = "Rule ID for S3 replication from destination to source"
  type        = string
}
