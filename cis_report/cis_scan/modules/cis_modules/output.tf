output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.inspector_cis_lambda.function_name
}

output "lambda_arn" {
  description = "ARN of Lambda function"
  value       = aws_lambda_function.inspector_cis_lambda.arn
}

output "lambda_role_name" {
  description = "IAM role used by Lambda"
  value       = aws_iam_role.inspector_lambda_role.name
}

output "lambda_policy_name" {
  description = "IAM policy attached to Lambda"
  value       = aws_iam_policy.inspector_lambda_policy.name
}
