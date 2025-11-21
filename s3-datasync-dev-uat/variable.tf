variable "region" {
  type        = string
  description = "AWS region for both accounts"
  default     = "ap-southeast-1"
}

variable "dev_profile" {
  type        = string
  description = "AWS CLI profile name for Dev account"
}

variable "uat_profile" {
  type        = string
  description = "AWS CLI profile name for UAT account"
}

variable "dev_bucket_name" {
  type        = string
  description = "Dev S3 bucket with model files"
}

variable "uat_bucket_name" {
  type        = string
  description = "UAT S3 bucket to receive model files"
}

# control whether to start the sync using terraform
variable "run_promotion" {
  type        = bool
  description = "If true, start the DataSync task in this apply"
  default     = false
}
