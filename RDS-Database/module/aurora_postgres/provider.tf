terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.16.0"
    }
  }
}

# Read the current version of the master secret created in this module
data "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master_creds_fix.id
}

locals {
  master_secret = jsondecode(data.aws_secretsmanager_secret_version.master.secret_string)
}

provider "postgresql" {
  alias     = "master"
  host      = aws_rds_cluster.aurora.endpoint
  port      = 5432
  username  = local.master_secret.username
  password  = local.master_secret.password
  database  = var.db_server_name
  sslmode   = "require"
  superuser = false
}
