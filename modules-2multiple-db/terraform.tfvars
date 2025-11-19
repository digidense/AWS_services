cluster_name    = "dbservercluster"
db_endpoint     = "dbserverclusteraurora.cluster-cavk0ucm2c8k.us-east-1.rds.amazonaws.com"
master_username = "dbmaster1"
master_password = "!#$%^&*()-_=+[]{}<>?:.,"
master_password_secret_arn = "arn:aws:secretsmanager:us-east-1:165220828225:secret:dbservercluster-aurora-master-credentials-GjgUEz"
databases = [
  {
    name    = "app_db1"
    schemas = ["public"]
  },
  {
    name    = "app_db2"
    schemas = ["public"]
  }
]
app_user_name        = "app_user"
app_user_secret_name = "dbservercluster-app-user-credentials"