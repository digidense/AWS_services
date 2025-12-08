variable "region" {
  default = "us-east-1"
}

# Account A
variable "account_a_profile" {
  default = "dest"
}

# Account B
variable "account_b_id" {
  default = "165220828225"
}

variable "account_a_id" {
  default = "473278020383"
}

variable "bucket_name" {
  default = "securityhub-export-bucket-12345" # change to globally unique
}

variable "sns_email" {
  default = "ashwini.kanagaraj@digidense.in"
}

variable "lambda_function_name" {
  default = "export-securityhub-findings"
}

variable "account_b_event_bus_arn" {
  type    = string
  default ="arn:aws:lambda:us-east-1:165220828225:function:export-securityhub-findings"
}