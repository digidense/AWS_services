# Aurora PostgreSQL with Secrets Manager & Terraform

- This Terraform setup creates an **Aurora PostgreSQL cluster** and a writer instance in the default VPC.
- It generates **random passwords** for the master user and app user, and stores them securely in **AWS Secrets Manager** using a KMS CMK.
- The module then reads the **master DB credentials from Secrets Manager** and uses them in the **PostgreSQL provider** to connect to the Aurora cluster.
- Using the PostgreSQL provider, Terraform creates the **application database**, a **database user (role)**, and assigns the necessary **schema, table, and sequence grants**.
- All important outputs like the **cluster endpoint**, **reader endpoint**, **security group**, subnet group, and **secret ARNs** are exposed as Terraform outputs.
- The goal of this setup is to have a **fully automated, secure, and repeatable** way to provision Aurora, manage credentials, and prepare the database for application use.
