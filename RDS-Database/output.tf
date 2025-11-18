output "aurora_endpoint" {
  value = module.aurora.aurora_endpoint
}

output "aurora_reader_endpoint" {
  value = module.aurora.aurora_reader_endpoint
}

output "aurora_cluster_id" {
  value = module.aurora.aurora_cluster_id
}

output "aurora_instance_id" {
  value = module.aurora.aurora_instance_id
}

output "aurora_security_group_id" {
  value = module.aurora.aurora_security_group_id
}

output "aurora_subnet_group_name" {
  value = module.aurora.aurora_subnet_group_name
}

output "app_db_secret_arn" {
  value = module.aurora.app_db_secret_arn
}

output "master_db_secret_arn" {
  value = module.aurora.master_db_secret_arn
}

output "kms_key_arn" {
  value = module.aurora.kms_key_arn
}

output "kms_alias_name" {
  value = module.aurora.kms_alias_name
}
