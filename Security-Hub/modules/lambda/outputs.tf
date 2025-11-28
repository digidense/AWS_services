output "lambda_arn" {
  value = aws_lambda_function.securityhub_export.arn
}

output "lambda_name" {
  value = aws_lambda_function.securityhub_export.function_name
}
