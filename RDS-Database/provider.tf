terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.16.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# This provider connects to Aurora using master credentials
provider "postgresql" {
  alias    = "master"
  host     = module.aurora.aurora_endpoint
  port     = 5432
  username = var.master_username
  password = "" # cannot use random here directly, we will handle via data source later if needed
  database = var.db_name
  sslmode  = "require"
  superuser = false
}
