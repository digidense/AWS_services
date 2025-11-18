module "aurora" {
  source = "./module/aurora_postgres"

  allowed_cidr            = var.allowed_cidr
  aurora_engine_version   = var.aurora_engine_version
  db_server_name          = var.db_server_name
  db_name                 = var.db_name
  db_username             = var.db_username
  master_username         = var.master_username
  db_instance_class       = var.db_instance_class
  security_group_name     = var.security_group_name
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window

}
