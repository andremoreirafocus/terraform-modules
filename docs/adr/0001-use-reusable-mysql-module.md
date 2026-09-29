# ADR 0001: Use a Reusable MySQL Module

- Status: Accepted
- Date: 2026-09-23

## Context

The project has separate stage and production environments. Both environments require an Amazon RDS MySQL database with the same core structure, while some database settings are expected to differ between environments.

The current MySQL configuration is in stage/data-stores/mysql. Its state is stored at:

```text
stage/data-stores/mysql/terraform.tfstate
```

The webserver configuration consumes the database root outputs address and port through remote state.

## Decision

Create a reusable MySQL module because the project has both stage and production environments.

The module will be located at:

```text
modules/data-stores/mysql/
```

The stage and production root configurations will call this module and maintain separate state keys. Backend configuration, provider configuration, credentials, and environment-specific module inputs remain in each environment root.

The module will initially preserve the current database configuration. It will expose the existing credentials inputs and outputs:

```text
Inputs:
- db_username
- db_password

Outputs:
- address
- port
```

The module is intended to support the following parameters:

- db_name
- identifier_prefix
- instance_class
- allocated_storage
- engine_version
- multi_az
- backup_retention_period
- skip_final_snapshot
- db_username
- db_password

Example stage configuration:

```hcl
module "mysql" {
  source = "../../../modules/data-stores/mysql"

  db_name                 = "example_database"
  identifier_prefix       = "terraform-stage"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  engine_version          = null
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  db_username             = var.db_username
  db_password             = var.db_password
}
```

Example production configuration:

```hcl
module "mysql" {
  source = "../../../modules/data-stores/mysql"

  db_name                 = "example_database"
  identifier_prefix       = "terraform-prod"
  instance_class          = "db.t3.small"
  allocated_storage       = 100
  engine_version          = null
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = false
  db_username             = var.db_username
  db_password             = var.db_password
}
```

The parameterization may be implemented in stages, depending on current and future environment requirements.

## State migration

The existing RDS instance must be preserved when it is moved into the module. The stage root will use:

```hcl
moved {
  from = aws_db_instance.example
  to   = module.mysql.aws_db_instance.example
}
```

This keeps the existing RDS instance associated with the new module address.
