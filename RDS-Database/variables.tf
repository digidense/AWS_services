variable "aws_region" {
  type = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to connect to the Aurora cluster"
  type        = string
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
}

variable "db_name" {
  description = "Initial database name for Aurora cluster (created by RDS)"
  type        = string
}

variable "app_db_name" {
  description = "Application database name (inside cluster, created via postgresql provider)"
  type        = string
}

variable "db_username" {
  description = "Application DB username"
  type        = string
}

variable "master_username" {
  description = "Master username for Aurora cluster"
  type        = string
}

variable "db_instance_class" {
  description = "Instance class for the Aurora writer instance"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name for the Aurora DB subnet group"
  type        = string
}

variable "security_group_name" {
  description = "Name for the Aurora security group"
  type        = string
}

variable "cluster_identifier" {
  description = "Aurora cluster identifier"
  type        = string
}

variable "instance_identifier" {
  description = "Aurora writer instance identifier"
  type        = string
}

variable "app_user_secret_name" {
  description = "Secrets Manager secret name for app user credentials"
  type        = string
}

variable "master_secret_name" {
  description = "Secrets Manager secret name for master credentials"
  type        = string
}

variable "kms_alias_name" {
  description = "Alias name for the KMS key used by Secrets Manager"
  type        = string
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on cluster deletion"
  type        = bool
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
}

variable "preferred_backup_window" {
  description = "Preferred backup window for the Aurora cluster"
  type        = string
}
