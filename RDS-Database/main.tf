module "aurora" {
  source = "./module/aurora_postgres"

  allowed_cidr            = var.allowed_cidr
  aurora_engine_version   = var.aurora_engine_version
  db_name                 = var.db_name
  app_db_name             = var.app_db_name
  db_username             = var.db_username
  master_username         = var.master_username
  db_instance_class       = var.db_instance_class
  db_subnet_group_name    = var.db_subnet_group_name
  security_group_name     = var.security_group_name
  cluster_identifier      = var.cluster_identifier
  instance_identifier     = var.instance_identifier
  app_user_secret_name    = var.app_user_secret_name
  master_secret_name      = var.master_secret_name
  kms_alias_name          = var.kms_alias_name
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window

}
