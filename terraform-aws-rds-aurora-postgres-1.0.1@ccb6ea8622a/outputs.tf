output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.aurora.port
}

output "cluster_id" {
  description = "Aurora cluster ID"
  value       = aws_rds_cluster.aurora.id
}

output "security_group_id" {
  description = "Aurora security group ID"
  value       = var.security_group_id
}

output "aurora_master_secret_arn" {
  description = "Secrets Manager ARN for Aurora master credentials"
  value       = aws_secretsmanager_secret.aurora_master_credentials.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for Secrets Manager and RDS encryption"
  value       = aws_kms_key.aurora_secrets_kms.arn
}

#################################################
# APP USER SECRET ARN
#################################################
output "app_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing app user credentials"
  value       = aws_secretsmanager_secret.app_user.arn
}

#################################################
# SECRETS KMS KEY ARN (OPTIONAL SEPARATE KMS FOR SECRETS)
#################################################
output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Secrets Manager secrets"
  value = (
  var.enable_kms_for_secrets && length(aws_kms_key.secrets_kms) > 0
  ? aws_kms_key.secrets_kms[0].arn
  : null
  )
}

#################################################
# CREATED DATABASES
#################################################
output "created_databases" {
  description = "Names of databases created"
  value       = [for db in postgresql_database.databases : db.name]
}
