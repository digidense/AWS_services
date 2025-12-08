variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_b_profile" {
  type    = string
  default = "source"
}
variable "account_a_id" {
  type    = string
  default = "473278020383"
}
variable "bucket_name" {
  type    = string
  default = "securityhub-export-bucket-12345" # change to globally unique name
}
variable "sns_email" {
  type    = string
  default = "ashwini.kanagaraj@digidense.in"
}
variable "lambda_function_name" {
  type    = string
  default = "export-securityhub-findings"
}