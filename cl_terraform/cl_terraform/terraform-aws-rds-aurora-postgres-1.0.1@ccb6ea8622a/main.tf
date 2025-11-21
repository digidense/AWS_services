#################################################
# KMS KEY FOR AURORA MASTER CREDENTIALS & RDS ENCRYPTION (existing)
#################################################

resource "aws_kms_key" "aurora_secrets_kms" {
  description         = "KMS key for Aurora master credentials and related secrets"
  enable_key_rotation = true

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-aurora-secrets-kms"
    }
  )
}

resource "aws_kms_alias" "aurora_secrets_kms_alias" {
  name          = "alias/${var.cluster_name}-aurora-secrets-kms"
  target_key_id = aws_kms_key.aurora_secrets_kms.key_id
}

#################################################
# OPTIONAL: KMS KEY FOR SECRETS MANAGER (new/conditional)
# Toggle with var.enable_kms_for_secrets
#################################################

resource "aws_kms_key" "secrets_kms" {
  count               = var.enable_kms_for_secrets ? 1 : 0
  description         = "KMS key for Secrets Manager DB credentials for ${var.cluster_name}"
  enable_key_rotation = true

  tags = var.tags
}

resource "aws_kms_alias" "secrets_kms_alias" {
  count         = var.enable_kms_for_secrets ? 1 : 0
  name          = "alias/${var.cluster_name}-secrets-kms"
  target_key_id = aws_kms_key.secrets_kms[0].key_id
}

#################################################
# SECRETS MANAGER - STORE MASTER CREDENTIALS
# Use the optional secrets_kms if enabled, otherwise
# fall back to aurora_secrets_kms (existing key).
#################################################

resource "aws_secretsmanager_secret" "aurora_master_credentials" {
  name = "${var.cluster_name}-flash-air"

  # Choose KMS: if a separate secrets_kms was created use it,
  # otherwise use the aurora_secrets_kms
  kms_key_id = length(aws_kms_key.secrets_kms) > 0 ? aws_kms_key.secrets_kms[0].arn : aws_kms_key.aurora_secrets_kms.arn

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-credential"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aurora_master_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_master_credentials.id

  # Store username & password as JSON
  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
  })
}

#################################################
# SUBNET GROUP & PARAMETER GROUPS
#################################################

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.cluster_name}-aurora-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  family = var.parameter_group_family
  name   = "${var.cluster_name}-aurora-cluster-params"

  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "aurora" {
  family = var.parameter_group_family
  name   = "${var.cluster_name}-aurora-db-params"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags
}

#################################################
# FINAL SNAPSHOT NAME
#################################################

locals {
  final_snapshot_id = var.skip_final_snapshot ? null : "${var.cluster_name}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

#################################################
# AURORA CLUSTER
#################################################

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.cluster_name}aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name

  # NOTE: These still need plaintext for RDS, but we also store them securely in Secrets Manager
  master_username = var.master_username
  master_password = var.master_password

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [var.security_group_id]

  storage_encrypted = var.storage_encrypted
  kms_key_id        = aws_kms_key.aurora_secrets_kms.arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = local.final_snapshot_id
  tags                            = var.tags
}

#################################################
# AURORA CLUSTER INSTANCES
#################################################

resource "aws_rds_cluster_instance" "aurora" {
  count              = var.instance_count
  identifier         = "${var.cluster_name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  db_parameter_group_name      = aws_db_parameter_group.aurora.name
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  publicly_accessible          = false
  tags                         = var.tags
}

#################################################
# ENHANCED MONITORING IAM ROLE
#################################################

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.cluster_name}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

#################################################
# -------------------------
# Additional Postgres management (for existing instance)
# - optional: read master password from existing secret (var.master_password_secret_arn)
# - create multiple DBs, schemas, and tables and create app user + store credentials
# -------------------------
#################################################

# Read master password from an existing Secrets Manager secret if provided
data "aws_secretsmanager_secret_version" "master_password" {
  count     = length(var.master_password_secret_arn) > 0 ? 1 : 0
  secret_id = var.master_password_secret_arn
}

locals {
  # If master password secret arn provided, parse secret_string, else use var.master_password
  master_password_from_secret = length(data.aws_secretsmanager_secret_version.master_password) > 0 ? data.aws_secretsmanager_secret_version.master_password[0].secret_string : var.master_password

  # Use this master password where needed for the PostgreSQL provider and local-exec table creation
  master_password = local.master_password_from_secret

  # Step 1: build a flat list of { db_name, schema_name }
  db_schema_list = flatten([
  for db in var.databases : [
  for s in db.schemas : {
    db_name     = db.name
    schema_name = s
  }
  ]
  ])

  # Step 2: convert that list into a map:
  # "db_name.schema_name" => { db_name = "", schema_name = "" }
  db_schemas = {
  for item in local.db_schema_list :
  "${item.db_name}.${item.schema_name}" => {
    db_name     = item.db_name
    schema_name = item.schema_name
  }
  }

  # Tables map from var.tables
  # key: "db.schema.table"
  tables_map = {
  for t in var.tables :
  "${t.db_name}.${t.schema_name}.${t.table_name}" => t
  }
}

############################################
# POSTGRESQL PROVIDER (FOR EXISTING INSTANCE)
# Only actually used when enable_db_bootstrap = true
############################################

provider "postgresql" {
  host     = aws_rds_cluster.aurora.endpoint
  port     = var.db_port
  database = "postgres" # admin DB; adjust if your admin user uses a different default DB
  username = var.master_username
  password = local.master_password
  sslmode  = "require"

  # Your user is not SUPERUSER
  superuser       = false
  connect_timeout = 300
}

############################################
# CREATE MULTIPLE DATABASES
############################################

resource "postgresql_database" "databases" {
  for_each = var.enable_db_bootstrap ? { for db in var.databases : db.name => db } : {}

  name             = each.value.name
  owner            = var.master_username
  lc_collate       = "en_US.utf8"
  lc_ctype         = "en_US.utf8"
  encoding         = "UTF8"
  template         = "template1"
  connection_limit = -1
}

############################################
# CREATE SCHEMAS IN EACH DATABASE
############################################

resource "postgresql_schema" "schemas" {
  for_each = var.enable_db_bootstrap ? local.db_schemas : {}

  name     = each.value.schema_name
  database = each.value.db_name
  owner    = var.master_username

  depends_on = [
    postgresql_database.databases
  ]
}

############################################
# CREATE TABLES INSIDE DB + SCHEMA
# Uses local-exec psql command. Ensure psql binary available.
############################################
resource "null_resource" "tables" {
  for_each = var.enable_db_bootstrap ? local.tables_map : {}

  provisioner "local-exec" {
    command = <<EOT
psql "host=${aws_rds_cluster.aurora.endpoint} port=${var.db_port} dbname=${each.value.db_name} user=${var.master_username} password='${local.master_password}' sslmode=require" \
  -c "CREATE SCHEMA IF NOT EXISTS ${each.value.schema_name};
      CREATE TABLE IF NOT EXISTS ${each.value.schema_name}.${each.value.table_name} (
        ${join(", ", each.value.columns)}
      );"
EOT
  }

  depends_on = [
    postgresql_database.databases,
    postgresql_schema.schemas
  ]
}

############################################
# APP USER CREATION
############################################

resource "random_password" "app_user" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?:.,"
}

resource "postgresql_role" "app_user" {
  count    = var.enable_db_bootstrap ? 1 : 0
  name     = var.app_user_name
  login    = true
  password = random_password.app_user.result
}

############################################
# GRANTS FOR APP USER
############################################

# Grant CONNECT + TEMP on each database
resource "postgresql_grant" "app_user_db" {
  for_each = var.enable_db_bootstrap ? postgresql_database.databases : {}

  database    = each.key
  role        = postgresql_role.app_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "TEMPORARY"]
}

# Grant default privileges on public schema for each database
resource "postgresql_default_privileges" "app_user_public_schema" {
  for_each = var.enable_db_bootstrap ? postgresql_database.databases : {}

  database    = each.key
  schema      = "public"
  role        = postgresql_role.app_user[0].name
  owner       = var.master_username
  object_type = "table"
  privileges  = ["INSERT", "UPDATE", "DELETE", "SELECT"]
}

############################################
# STORE APP USER CREDENTIALS IN SECRETS MANAGER
# Use the optional secrets_kms if enabled.
############################################

resource "aws_secretsmanager_secret" "app_user" {
  # Option 1: always create (recommended)
  name       = var.app_user_secret_name
  kms_key_id = length(aws_kms_key.secrets_kms) > 0 ? aws_kms_key.secrets_kms[0].arn : null

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app_user" {
  secret_id = aws_secretsmanager_secret.app_user.id
  secret_string = jsonencode({
    username = var.app_user_name
    password = random_password.app_user.result
  })
}
