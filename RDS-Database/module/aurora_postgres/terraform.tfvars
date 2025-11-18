aws_region   = "us-east-1"
allowed_cidr = "0.0.0.0/0"

aurora_engine_version = "17.4"

db_name         = "appdbfix"
app_db_name     = "apply"
db_username     = "appuserfix"
master_username = "dbmaster"

db_instance_class    = "db.t3.medium"
db_subnet_group_name = "aurora-subnet-group-fix"
security_group_name  = "aurora-sg-fix"
cluster_identifier   = "tfauroraclusterfix"
instance_identifier  = "tfaurorainstancefix"

app_user_secret_name = "tf-db-credential"
master_secret_name   = "tf-db-master-credential"
kms_alias_name       = "alias/terraform-secrets-key-fix"

skip_final_snapshot     = true
backup_retention_period = 7
preferred_backup_window = "07:00-09:00"
