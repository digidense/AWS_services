variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Aurora PostgreSQL cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to associate with the Aurora instances"
  type        = string
}

variable "db_port" {
  description = "Port for the PostgreSQL database"
  type        = number
  default     = 5432
}

############################
# Engine / Cluster Settings
############################

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.12"
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "postgres"
}

variable "master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Master password for the Aurora cluster (used if master_password_secret_arn is empty)"
  type        = string
  sensitive   = true
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
  description = "Daily backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql"]
}

variable "deletion_protection" {
  description = "Enable deletion protection on the cluster"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

############################
# Instance Settings
############################

variable "instance_count" {
  description = "Number of Aurora instances in the cluster"
  type        = number
  default     = 2
}

variable "instance_class" {
  description = "Instance class/size for the Aurora instances"
  type        = string
  default     = "db.r6g.large"
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (seconds)"
  type        = number
  default     = 60
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "aurora-postgresql15"
}

############################
# App DB User / Secrets
############################

variable "app_user_name" {
  description = "Database app user name to be created in PostgreSQL"
  type        = string
  default     = "db-app-user"
}

variable "app_user_secret_name" {
  description = "Name of the Secrets Manager secret to store the app user's DB credentials"
  type        = string
  default     = "secret-flash-drived"
}

variable "enable_kms_for_secrets" {
  description = "Whether to create/use a KMS key for encrypting Secrets Manager secrets"
  type        = bool
  default     = true
}

variable "master_password_secret_arn" {
  description = "If provided, Secrets Manager ARN where the master password is stored (takes precedence over master_password variable)"
  type        = string
  default     = ""
}

############################
# PostgreSQL Logical Objects
############################

variable "databases" {
  description = "List of databases and their schemas to create inside the cluster"
  type = list(object({
    name    = string
    schemas = list(string)
  }))
  default = []
}

variable "tables" {
  description = "List of tables to create in specific databases and schemas"
  type = list(object({
    db_name     = string
    schema_name = string
    table_name  = string
    columns     = list(string) # e.g. ["id SERIAL PRIMARY KEY","job_name VARCHAR(100) NOT NULL","status VARCHAR(50) NOT NULL","last_run TIMESTAMP"]
  }))
  default = []
}

############################
# Parameter Groups
############################

variable "cluster_parameters" {
  description = "List of cluster-level parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_parameters" {
  description = "List of instance-level DB parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

############################
# Tags
############################

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_db_bootstrap" {
  description = "Enable PostgreSQL objects creation (DB/schema/tables/app user)"
  type        = bool
  default     = false
}
