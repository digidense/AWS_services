###############################################################################
# OUTPUTS
###############################################################################

output "cluster_endpoint" {
  description = "Aurora cluster endpoint (writer)"
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

output "aurora_master_secret_arn" {
  description = "Secrets Manager ARN for Aurora master credentials"
  value       = aws_secretsmanager_secret.aurora_master_credentials.arn
}

output "aurora_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
  description = "The writer endpoint of the Aurora PostgreSQL cluster"
}


