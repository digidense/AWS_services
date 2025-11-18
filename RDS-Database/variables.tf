variable "allowed_cidr" {
  description = "CIDR allowed to connect to the Aurora cluster"
  type        = string
  default     = "0.0.0.0/0"
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.12"
}

variable "db_server_name" {
  description = "Initial database name for Aurora cluster (created by RDS)"
  type        = string
  default = "tfdbserver"
}

variable "db_name" {
  description = "Application database name (inside cluster, created via postgresql provider)"
  type        = string
  default = "tfdb"
}

variable "db_username" {
  description = "Application DB username"
  type        = string
  default = "appuserfix"
}

variable "master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default = "dbmaster"
}

variable "db_instance_class" {
  description = "Instance class for the Aurora writer instance"
  type        = string
  default     = "db.t3.medium"
}



variable "security_group_name" {
  description = "Name for the Aurora security group"
  type        = string
  default = "aurora-subnet-group-fix"
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on cluster deletion"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window for the Aurora cluster"
  type        = string
  default     = "07:00-09:00"
}
