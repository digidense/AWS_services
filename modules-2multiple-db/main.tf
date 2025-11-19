############################################
# KMS KEY FOR SECRETS MANAGER
############################################

resource "aws_kms_key" "secrets_kms" {
  count               = var.enable_kms_for_secrets ? 1 : 0
  description         = "KMS key for Secrets Manager DB credentials for ${var.cluster_name}"
  enable_key_rotation = true

  tags = var.tags
}

resource "aws_kms_alias" "secrets_kms_alias" {
  count        = var.enable_kms_for_secrets ? 1 : 0
  name         = "alias/${var.cluster_name}-secrets-kms"
  target_key_id = aws_kms_key.secrets_kms[0].id
}

############################################
# READ MASTER PASSWORD FROM SECRETS MANAGER
############################################

data "aws_secretsmanager_secret_version" "master_password" {
  secret_id = var.master_password_secret_arn
}

locals {
  master_password = data.aws_secretsmanager_secret_version.master_password.secret_string
}

############################################
# POSTGRESQL PROVIDER (FOR EXISTING INSTANCE)
############################################

provider "postgresql" {
  host     = var.db_endpoint
  port     = var.db_port
  database = "postgres"              # admin DB; adjust if your admin user uses a different default DB
  username = var.master_username
  password = local.master_password
  sslmode  = "require"

  # If your user is not SUPERUSER, you can set superuser = false
  superuser = false
}

############################################
# CREATE MULTIPLE DATABASES
############################################

resource "postgresql_database" "databases" {
  for_each = { for db in var.databases : db.name => db }

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

locals {
  db_names = [for db in var.databases : db.name]
}

resource "postgresql_schema" "schemas" {
  for_each = {
  for db in var.databases : db.name => db
  }

  name     = "public"
  database = each.value.name
  owner    = var.master_username

  depends_on = [
    postgresql_database.databases
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
  name     = var.app_user_name
  login    = true
  password = random_password.app_user.result
}

############################################
# GRANTS FOR APP USER
############################################

# Grant CONNECT + TEMP on each database
resource "postgresql_grant" "app_user_db" {
  for_each = postgresql_database.databases

  database    = each.key
  role        = postgresql_role.app_user.name
  object_type = "database"
  privileges  = ["CONNECT", "TEMPORARY"]
}

# Grant usage on public schema for each database
resource "postgresql_default_privileges" "app_user_public_schema" {
  for_each = postgresql_database.databases

  database    = each.key
  schema      = "public"
  role        = postgresql_role.app_user.name
  owner       = var.master_username
  object_type = "table"
  privileges  = ["INSERT", "UPDATE", "DELETE", "SELECT"]
}

############################################
# STORE APP USER CREDENTIALS IN SECRETS MANAGER
############################################

resource "aws_secretsmanager_secret" "app_user" {
  name       = var.app_user_secret_name
  kms_key_id = var.enable_kms_for_secrets ? aws_kms_key.secrets_kms[0].arn : null

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app_user" {
  secret_id = aws_secretsmanager_secret.app_user.id
  secret_string = jsonencode({
    username = var.app_user_name
    password = random_password.app_user.result
  })
}
