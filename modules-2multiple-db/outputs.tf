output "app_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing app user credentials"
  value       = aws_secretsmanager_secret.app_user.arn
}

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Secrets Manager secrets"
  value = (
  var.enable_kms_for_secrets && length(aws_kms_key.secrets_kms) > 0
  ? aws_kms_key.secrets_kms[0].arn
  : null
  )
}



output "created_databases" {
  description = "Names of databases created"
  value       = [for db in postgresql_database.databases : db.name]
}
