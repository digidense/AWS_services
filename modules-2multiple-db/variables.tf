variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "Logical name of the DB cluster (for naming KMS, secrets, etc.)"
  type        = string
}

variable "db_endpoint" {
  description = "Endpoint (hostname) of the existing PostgreSQL/Aurora instance"
  type        = string
}

variable "db_port" {
  description = "Port of the existing PostgreSQL instance"
  type        = number
  default     = 5432
}

variable "master_username" {
  description = "Admin username for PostgreSQL (e.g., postgres or dbmaster1)"
  type        = string
}

variable "master_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing the admin password"
  type        = string
}

variable "databases" {
  description = "List of databases and schemas to create"
  type = list(object({
    name    = string
    schemas = list(string)
  }))
}

variable "app_user_name" {
  description = "Application DB user to create"
  type        = string
}

variable "app_user_secret_name" {
  description = "Name for Secrets Manager secret to store app user password"
  type        = string
}

variable "enable_kms_for_secrets" {
  description = "Whether to create a dedicated KMS key for Secrets Manager"
  type        = bool
  default     = true
}

variable "master_password" {
  description = "Master password for the DB cluster"
  type        = string
  sensitive   = true
}
