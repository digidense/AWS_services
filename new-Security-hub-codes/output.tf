output "central_lambda_arn" {
  value = module.account_b.central_lambda_arn
}

output "central_bucket_arn" {
  value = module.account_b.central_bucket_arn
}

output "account_b_event_bus_arn" {
  value = module.account_b.account_b_event_bus_arn
}
