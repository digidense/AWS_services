cluster_name      = "dbservercluster"
region            = "us-east-1"
vpc_id            = "vpc-0f1074e15190e4869"
vpc_cidr          = "172.31.0.0/16"
subnet_ids        = ["subnet-04b7ba2fee6212c88", "subnet-099f2e0d6bede6fa2"]
security_group_id = "sg-091fff2d4a3406b0e"
master_password   = "!#$%^&*()-_=+[]{}<>?:.,"
db_port           = 5432

enable_db_bootstrap = true

databases = [
  {
    name    = "appdb"
    schemas = ["public"]
  },
  {
    name    = "loggingdb"
    schemas = ["public"]
  }
]

tables = [
  {
    db_name     = "appdb"
    schema_name = "public"
    table_name  = "users"
    columns = [
      "id SERIAL PRIMARY KEY",
      "username VARCHAR(100) NOT NULL",
      "email VARCHAR(255) NOT NULL",
      "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    ]
  },
  {
    db_name     = "appdb"
    schema_name = "public"
    table_name  = "orders"
    columns = [
      "id SERIAL PRIMARY KEY",
      "user_id INT NOT NULL",
      "amount NUMERIC(10,2) NOT NULL",
      "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    ]
  },
  {
    db_name     = "loggingdb"
    schema_name = "public"
    table_name  = "app_logs"
    columns = [
      "id BIGSERIAL PRIMARY KEY",
      "level VARCHAR(10) NOT NULL",
      "message TEXT NOT NULL",
      "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    ]
  },
  {
    db_name     = "loggingdb"
    schema_name = "public"
    table_name  = "audit"
    columns = [
      "id BIGSERIAL PRIMARY KEY",
      "user_name VARCHAR(100)",
      "action VARCHAR(100) NOT NULL",
      "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    ]
  }
]
