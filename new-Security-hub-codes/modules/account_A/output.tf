output "central_lambda_arn" {
  value = aws_lambda_function.exporter.arn
}

output "central_bucket_arn" {
  value = aws_s3_bucket.securityhub_bucket.arn
}

output "account_b_event_bus_arn" {
  value = aws_cloudwatch_event_bus.forward_bus.arn
}
