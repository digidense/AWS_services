#################################################
# KMS KEY FOR AURORA MASTER CREDENTIALS & RDS ENCRYPTION
#################################################
resource "aws_kms_key" "aurora_secrets_kms" {
  description         = "KMS key for Aurora master credentials and related secrets"
  enable_key_rotation = true
  tags = merge(var.tags, { "Name" = "${var.cluster_name}-aurora-secrets-kms" })
}

resource "aws_kms_alias" "aurora_secrets_kms_alias" {
  name          = "alias/${var.cluster_name}-aurora-secrets-kms-az"
  target_key_id = aws_kms_key.aurora_secrets_kms.key_id
}

#################################################
# OPTIONAL: KMS KEY FOR SECRETS MANAGER
#################################################
resource "aws_kms_key" "secrets_kms" {
  count               = var.enable_kms_for_secrets ? 1 : 0
  description         = "KMS key for Secrets Manager DB credentials for ${var.cluster_name}"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_kms_alias" "secrets_kms_alias" {
  count         = var.enable_kms_for_secrets ? 1 : 0
  name          = "alias/${var.cluster_name}-secrets-kms"
  target_key_id = aws_kms_key.secrets_kms[0].key_id
}

#################################################
# SECRETS MANAGER - STORE MASTER CREDENTIALS (Auto-updating host)
#################################################
resource "aws_secretsmanager_secret" "aurora_master_credentials" {
  name      = "${var.cluster_name}-flash-air-jh"
  kms_key_id = length(aws_kms_key.secrets_kms) > 0 ? aws_kms_key.secrets_kms[0].arn : aws_kms_key.aurora_secrets_kms.arn
  tags = merge(var.tags, { "Name" = "${var.cluster_name}-credential" })
}

# Create only AFTER cluster endpoint becomes available (or manual endpoint provided)
resource "aws_secretsmanager_secret_version" "aurora_master_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_master_credentials.id

  secret_string = jsonencode({
    host     = var.manual_endpoint != "" ? var.manual_endpoint : aws_rds_cluster.aurora.endpoint
    port     = var.db_port
    dbname   = var.database_name
    username = var.master_username
    password = var.master_password
  })

  depends_on = [aws_rds_cluster.aurora]
}

#################################################
# SUBNET GROUP & PARAMETER GROUPS
#################################################
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.cluster_name}-aurora-subnet-group-kl"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  family = var.parameter_group_family
  name   = "${var.cluster_name}-aurora-cluster-params-kl"

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
  name   = "${var.cluster_name}-aurora-db-params-kl"

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

  engine         = aws_rds_cluster.aurora.engine
  engine_version = aws_rds_cluster.aurora.engine_version

  db_parameter_group_name      = aws_db_parameter_group.aurora.name
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  publicly_accessible          = false
  tags                         = var.tags
}

#################################################
# ENHANCED MONITORING IAM
#################################################
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.cluster_name}-rds-enhanced-monitoring-kl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

#################################################
# VALIDATE: require DB/schema/table lists when enable_db_bootstrap = true
# This validation runs as a local-exec (Bash). It will fail early with clear message.
#################################################
resource "null_resource" "validate_bootstrap_inputs" {
  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
databasesCount=${length(var.databases)}
tablesCount=${length(var.tables)}

if [ $databasesCount -le 0 ]; then
  echo "enable_db_bootstrap is true but 'databases' list is empty. Add at least one database in var.databases."
  exit 1
fi

if [ $tablesCount -le 0 ]; then
  echo "enable_db_bootstrap is true but 'tables' list is empty. Add at least one table in var.tables."
  exit 1
fi

echo "Bootstrap inputs validation passed: $databasesCount database(s), $tablesCount table(s)."
EOT
  }
}

#################################################
# WAIT FOR ENDPOINT (uses manual_endpoint if provided)
#################################################
resource "null_resource" "wait_for_rds" {
  provisioner "local-exec" {
    environment = {
      PGPASSWORD = var.master_password
    }

    command = <<EOT
#!/bin/bash
host="${var.manual_endpoint}"
port=5432
user="${var.master_username}"
max_attempts=30

echo "Waiting for Aurora to become available..."
for i in $(seq 1 $max_attempts); do
  psql -h $host -p $port -U $user -d postgres -c "\q" 2>/dev/null && echo "Aurora is ready!" && exit 0
  echo "Attempt $i: Aurora not ready yet. Sleeping 10s..."
  sleep 10
done

echo "Aurora endpoint did not become ready in time."
exit 1
EOT
  }
}

#################################################
# POSTGRESQL PROVIDER (uses manual_endpoint if provided)
#################################################
provider "postgresql" {
  host     = var.manual_endpoint != "" ? var.manual_endpoint : aws_rds_cluster.aurora.endpoint
  port     = var.db_port
  database = "postgres"
  username = var.master_username
  password = var.master_password
  sslmode  = "require"
  superuser       = false
  connect_timeout = 300
}

#################################################
# DATABASE CREATION
#################################################
resource "postgresql_database" "databases" {
  for_each = { for db in var.databases : db.name => db }

  name              = each.value.name
  owner             = local.aurora_master_username
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"   # Match the template database collation
  lc_ctype          = "en_US.UTF-8"   # Match the template database collation
  template          = "template1"      # Ensures proper template
  allow_connections = true
  depends_on = [null_resource.wait_for_rds]
}

#################################################
# SCHEMA CREATION
#################################################
locals {
  db_schema_list = flatten([
    for db in var.databases : [
      for s in db.schemas : {
        db_name     = db.name
        schema_name = s
      }
    ]
  ])

  db_schemas = {
    for item in local.db_schema_list :
    "${item.db_name}.${item.schema_name}" => item
  }
}

resource "postgresql_schema" "schemas" {
  for_each = var.enable_db_bootstrap ? local.db_schemas : {}

  name     = each.value.schema_name
  database = each.value.db_name
  owner    = var.master_username

  depends_on = [postgresql_database.databases]
}

#################################################
# TABLE CREATION
#################################################
locals {
  # Map of db_name.schema_name.table_name -> table object
  tables_map = {
    for t in var.tables :
    "${t.db_name}.${t.schema_name}.${t.table_name}" => t
  }
}

resource "null_resource" "create_tables" {
  for_each = var.enable_db_bootstrap ? local.tables_map : {}

  provisioner "local-exec" {
    environment = {
      PGPASSWORD = var.master_password
    }

    command = <<EOT
#!/bin/bash
psql -h ${var.manual_endpoint} -U ${var.master_username} -d ${each.value.db_name} -c "
CREATE SCHEMA IF NOT EXISTS ${each.value.schema_name};
CREATE TABLE IF NOT EXISTS ${each.value.schema_name}.${each.value.table_name} (
  ${join(", ", each.value.columns)}
);
"
EOT
  }

  depends_on = [postgresql_schema.schemas]
}

#################################################
# APP USER + GRANTS
#################################################
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

  depends_on = [null_resource.wait_for_rds]
}

resource "postgresql_grant" "app_user_db" {
  for_each = var.enable_db_bootstrap ? postgresql_database.databases : {}

  database    = each.key
  role        = postgresql_role.app_user[0].name
  object_type = "database"
  privileges  = ["CONNECT", "TEMPORARY"]

  depends_on = [postgresql_role.app_user]
}

resource "postgresql_default_privileges" "app_user_public_schema" {
  for_each = var.enable_db_bootstrap ? postgresql_database.databases : {}

  database    = each.key
  schema      = "public"
  role        = postgresql_role.app_user[0].name
  owner       = var.master_username
  object_type = "table"
  privileges  = ["INSERT", "UPDATE", "DELETE", "SELECT"]

  depends_on = [postgresql_role.app_user]
}

#################################################
# STORE APP USER CREDENTIALS
#################################################
resource "aws_secretsmanager_secret" "app_user" {
  name = var.app_user_secret_name
  kms_key_id = length(aws_kms_key.secrets_kms) > 0 ? aws_kms_key.secrets_kms[0].arn : aws_kms_key.aurora_secrets_kms.arn
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app_user" {
  secret_id = aws_secretsmanager_secret.app_user.id
  secret_string = jsonencode({
    username = var.app_user_name
    password = random_password.app_user.result
    host     = var.manual_endpoint != "" ? var.manual_endpoint : aws_rds_cluster.aurora.endpoint
    port     = var.db_port
    dbname   = var.database_name
  })

  depends_on = [postgresql_role.app_user]
}

data "aws_secretsmanager_secret" "aurora_master" {
  name = var.app_user_secret_name
}

data "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = data.aws_secretsmanager_secret.aurora_master.id
}

locals {
  aurora_master_secret_json = jsondecode(
    data.aws_secretsmanager_secret_version.aurora_master.secret_string
  )

  aurora_master_username = local.aurora_master_secret_json.username
  aurora_master_password = local.aurora_master_secret_json.password
}
