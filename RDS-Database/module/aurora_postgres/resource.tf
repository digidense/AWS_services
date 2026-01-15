#################################################
# PASSWORDS
#################################################

resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:;<>?,.|\\" # no / @ " or space
}

resource "random_password" "app_user" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:;<>?,.|\\"
}

#################################################
# DEFAULT VPC & SUBNETS
#################################################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

#################################################
# KMS FOR SECRETS MANAGER
#################################################

resource "aws_kms_key" "secrets" {
  description             = "KMS key for encrypting DB credentials in Secrets Manager (fix)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets_alias" {
  name          = "alias/terraform-secrets-key-fix"
  target_key_id = aws_kms_key.secrets.key_id
}

#################################################
# SECRETS MANAGER - APP USER
#################################################

resource "aws_secretsmanager_secret" "app_db_user_fix" {
  name        = "tf-db-credential"
  description = "Credentials for application DB user (app_user) - fix"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = {
    created_by = "terraform"
    purpose    = "fix"
  }
}

resource "aws_secretsmanager_secret_version" "app_db_user_version_fix" {
  secret_id = aws_secretsmanager_secret.app_db_user_fix.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.app_user.result
    engine   = "aurora-postgresql"
    host     = aws_rds_cluster.aurora.endpoint
    port     = 5432
    dbname   = var.db_server_name
  })
}

#################################################
# SECRETS MANAGER - MASTER USER
#################################################
resource "aws_secretsmanager_secret" "master_creds_fix" {
  name        = "tf-db-master-credential"
  description = "Aurora cluster master credentials - fix"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = {
    created_by = "terraform"
    purpose    = "fix"
  }
}

resource "aws_secretsmanager_secret_version" "master_creds_version_fix" {
  secret_id = aws_secretsmanager_secret.master_creds_fix.id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "aurora-postgresql"
  })
}

#################################################
# NETWORKING - SUBNET GROUP & SECURITY GROUP
#################################################

resource "aws_db_subnet_group" "aurora_subnets" {
  name        = "db_sg"
  subnet_ids  = data.aws_subnets.default.ids
  description = "Subnet group for Aurora cluster in default VPC (fix)"
}

resource "aws_security_group" "aurora_sg" {
  name        = var.security_group_name
  description = "Allow Postgres access to Aurora (fix)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "Allow Postgres access from allowed CIDR"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#################################################
# AURORA POSTGRESQL CLUSTER
#################################################

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "tf-aurora-cluster-fix"
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_engine_version

  master_username = var.master_username
  master_password = random_password.master.result

  database_name                   = var.db_server_name
  db_subnet_group_name            = aws_db_subnet_group.aurora_subnets.name
  vpc_security_group_ids          = [aws_security_group.aurora_sg.id]
  storage_encrypted               = true
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = false
  skip_final_snapshot             = true
  backup_retention_period         = 7
  preferred_backup_window         = "07:00-09:00"
  apply_immediately               = true
}

resource "aws_rds_cluster_instance" "writer" {
  identifier                   = "tf-aurora-instance-1-fix"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = "db.r6g.large" # change to smaller for cheaper (e.g. db.t3.medium)
  engine                       = aws_rds_cluster.aurora.engine
  engine_version               = aws_rds_cluster.aurora.engine_version
  publicly_accessible          = true
  db_subnet_group_name         = aws_db_subnet_group.aurora_subnets.name
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring_role.arn
  depends_on                   = [aws_rds_cluster.aurora]
}

#################################################
# POSTGRESQL: DB + ROLE + GRANTS
#################################################

resource "postgresql_database" "app_db_fix" {
  provider = postgresql.master
  name     = var.db_name

  depends_on = [
    aws_rds_cluster_instance.writer
  ]
}

resource "postgresql_role" "app_user_fix" {
  provider = postgresql.master

  name     = var.db_username
  password = random_password.app_user.result

  login     = true
  superuser = false

  depends_on = [
    aws_rds_cluster_instance.writer,
    postgresql_database.app_db_fix
  ]
}

resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attach" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "postgresql_grant" "app_user_db_grant_fix" {
  provider    = postgresql.master
  database    = var.db_server_name
  role        = postgresql_role.app_user_fix.name
  object_type = "database"
  privileges  = ["CONNECT"]

  depends_on = [
    aws_rds_cluster_instance.writer,
    postgresql_database.app_db_fix,
    postgresql_role.app_user_fix
  ]
}

resource "postgresql_grant" "schema_usage_fix" {
  provider    = postgresql.master
  database    = var.db_server_name
  role        = postgresql_role.app_user_fix.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [
    aws_rds_cluster_instance.writer,
    postgresql_database.app_db_fix,
    postgresql_role.app_user_fix
  ]
}

resource "postgresql_grant" "table_privs_fix" {
  provider    = postgresql.master
  database    = var.db_server_name
  role        = postgresql_role.app_user_fix.name
  schema      = "public"
  object_type = "table"
  privileges = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "TRUNCATE",
    "REFERENCES",
    "TRIGGER"
  ]

  depends_on = [
    aws_rds_cluster_instance.writer,
    postgresql_database.app_db_fix,
    postgresql_role.app_user_fix
  ]
}

resource "postgresql_grant" "sequence_privs_fix" {
  provider    = postgresql.master
  database    = var.db_server_name
  role        = postgresql_role.app_user_fix.name
  schema      = "public"
  object_type = "sequence"
  privileges = [
    "USAGE",
    "SELECT",
    "UPDATE"
  ]

  depends_on = [
    aws_rds_cluster_instance.writer,
    postgresql_database.app_db_fix,
    postgresql_role.app_user_fix
  ]
}

resource "aws_lambda_function" "rotation" {
  function_name = "aurora-db-rotation-fix"
  handler       = "index.handler"
  runtime       = "python3.9"

  role     = aws_iam_role.lambda_rotation_role.arn
  filename = "lambda_rotation.py.zip"

}

resource "aws_iam_role" "lambda_rotation_role" {
  name = "lambda_rotation_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rotation_basic" {
  role       = aws_iam_role.lambda_rotation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "rotation_secrets" {
  role       = aws_iam_role.lambda_rotation_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_secretsmanager_secret_rotation" "app_user_rotation" {
  secret_id           = aws_secretsmanager_secret.app_db_user_fix.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_rotation" "master_rotation" {
  secret_id           = aws_secretsmanager_secret.master_creds_fix.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  rotation_rules {
    automatically_after_days = 30
  }
  depends_on = [
    aws_lambda_permission.allow_secretsmanager
  ]
}
resource "aws_lambda_permission" "allow_secretsmanager" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}
