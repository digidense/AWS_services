# RDS Aurora PostgreSQL
module "rds_aurora" {
  source = "./terraform-aws-rds-aurora-postgres-1.0.1@ccb6ea8622a"

  ################################
  # Core / Network
  ################################
  region           = var.region
  cluster_name     = var.cluster_name
  vpc_id           = var.vpc_id
  vpc_cidr         = var.vpc_cidr
  subnet_ids       = var.subnet_ids
  security_group_id = var.security_group_id
  db_port          = var.db_port

  ################################
  # Engine / Cluster Settings
  ################################
  engine_version                  = var.engine_version
  database_name                   = var.database_name
  master_username                 = var.master_username
  master_password                 = var.master_password
  storage_encrypted               = var.storage_encrypted
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  parameter_group_family          = var.parameter_group_family

  ################################
  # Instance Settings
  ################################
  instance_count               = var.instance_count
  instance_class               = var.instance_class
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval

  ################################
  # App DB User / Secrets
  ################################
  app_user_name            = var.app_user_name
  app_user_secret_name     = var.app_user_secret_name
  enable_kms_for_secrets   = var.enable_kms_for_secrets
  master_password_secret_arn = var.master_password_secret_arn

  ################################
  # PostgreSQL Logical Objects
  ################################
  databases = var.databases
  tables    = var.tables
  enable_db_bootstrap = var.enable_db_bootstrap
  ################################
  # Parameter Groups
  ################################
  cluster_parameters = var.cluster_parameters
  db_parameters      = var.db_parameters

  ################################
  # Tags
  ################################
  tags = var.tags
}
