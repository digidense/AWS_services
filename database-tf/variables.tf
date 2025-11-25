variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "db_port" {
  description = "Port for the PostgreSQL database"
  type        = number
  default     = 5432
}

variable "db_endpoint" {
  description = "Aurora cluster endpoint (set after first apply)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.12"
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "postgres"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Master password (fallback if not using existing secret). If you want to read the password from Secrets Manager in the same account, set use_master_password_from_secret = true and provide master_password_secret_arn."
  type        = string
  sensitive   = true
  default     = ""
}

variable "use_master_password_from_secret" {
  description = "Set to true to read master password from existing Secrets Manager secret in the same account (requires master_password_secret_arn)."
  type        = bool
  default     = false
}

variable "master_password_secret_arn" {
  description = "Optional: ARN of Secrets Manager secret containing master creds in the same account."
  type        = string
  default     = ""
}

variable "storage_encrypted" {
  description = "Whether to encrypt storage"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql"]
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 2
}

variable "instance_class" {
  description = "Instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 60
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "aurora-postgresql15"
}

variable "app_user_secret_name" {
  description = "Base name of the Secrets Manager secret to store the app user's DB credentials (a short random suffix will be added to avoid collisions)"
  type        = string
  default     = "secret-flash-db-za"
}

variable "cluster_parameters" {
  description = "Cluster parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_parameters" {
  description = "DB parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_kms_for_secrets" {
  type    = bool
  default = false
}

variable "databases" {
  type = list(object({
    name    = string
    schemas = list(string)
  }))
  default = []
}

variable "tables" {
  type = list(object({
    db_name     = string
    schema_name = string
    table_name  = string
    columns     = list(string)
  }))
  default = []
}

variable "app_user_name" {
  description = "Database app user name to be created in PostgreSQL"
  type        = string
  default     = "db-app-user"
}

variable "enable_db_bootstrap" {
  description = "Enable generation of SQL files for DB bootstrap (these files must be run from a host that can reach the DB)"
  type        = bool
  default     = true
}

variable "manual_endpoint" {
  type        = string
  description = "Manually provided Aurora endpoint. Leave empty to use cluster endpoint."
  default     = "dbserverclusteraurora.cluster-cavk0ucm2c8k.us-east-1.rds.amazonaws.com"
}


