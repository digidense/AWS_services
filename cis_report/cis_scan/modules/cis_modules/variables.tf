variable "lambda_role_name" {
  description = "IAM Role name for Lambda"
  type        = string
  default     = "inspector-cis-lambda-role"
}

variable "lambda_policy_name" {
  description = "IAM Policy name for Lambda"
  type        = string
  default     = "inspector-cis-lambda-policy"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "inspector-cis-report-lambda"
}

variable "lambda_zip_file" {
  description = "ZIP file containing Lambda code"
  type        = string
  default     = "lambda_function.zip"
}

variable "s3_bucket_name" {
  description = "S3 bucket to store CIS reports"
  type        = string
  default     = "my-bucket-987668"
}
