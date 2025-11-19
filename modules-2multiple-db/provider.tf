terraform {
  required_version = ">= 1.0.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.4.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.21.0"
    }
  }
}

provider "aws" {
  region = var.region
}
