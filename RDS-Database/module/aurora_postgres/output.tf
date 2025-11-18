output "aurora_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "Aurora cluster writer endpoint"
}

output "aurora_reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "Aurora cluster reader endpoint"
}

output "aurora_cluster_id" {
  value       = aws_rds_cluster.aurora.id
  description = "Aurora cluster ID"
}

output "aurora_instance_id" {
  value       = aws_rds_cluster_instance.writer.id
  description = "Aurora writer instance ID"
}

output "aurora_security_group_id" {
  value       = aws_security_group.aurora_sg.id
  description = "Security group ID used by Aurora"
}

output "aurora_subnet_group_name" {
  value       = aws_db_subnet_group.aurora_subnets.name
  description = "Subnet group name used by Aurora"
}

output "app_db_secret_arn" {
  value       = aws_secretsmanager_secret.app_db_user_fix.arn
  description = "Secrets Manager ARN holding app DB user credentials"
}

output "master_db_secret_arn" {
  value       = aws_secretsmanager_secret.master_creds_fix.arn
  description = "Secrets Manager ARN holding master DB credentials"
}

output "kms_key_arn" {
  value       = aws_kms_key.secrets.arn
  description = "KMS key ARN used to encrypt secrets"
}

output "kms_alias_name" {
  value       = aws_kms_alias.secrets_alias.name
  description = "Alias name of the KMS key"
}
