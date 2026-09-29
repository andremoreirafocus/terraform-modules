# Migrating a MySQL Root Configuration to This Module

This repository supplies only `modules/data-stores/mysql`; it has no `stage`, `prod`, or other environment root configuration and holds no Terraform state. Perform this migration in the separate repository that owns the existing RDS configuration and state.

The module creates `aws_db_instance.example` and exports `db_address` and `db_port`. It accepts `db_username` and `db_password`.

## 1. Keep root-only concerns in the consumer

Leave the configured AWS provider, backend, input-variable declarations, credential-loading mechanism, and state in the environment root. Do not add a `backend` or configured `provider` block to this module.

## 2. Replace the root resource with the module call

In the existing root configuration, replace the standalone RDS resource with a module call. Adjust the source path to where this repository is checked out or use a pinned VCS source.

```hcl
module "mysql" {
  source = "../terraform-modules/modules/data-stores/mysql"

  db_username = var.db_username
  db_password = var.db_password
}
```

Re-export the module outputs if other configurations consume the root's state:

```hcl
output "db_address" {
  value = module.mysql.db_address
}

output "db_port" {
  value = module.mysql.db_port
}
```

Update downstream consumers to use the new output names, or retain their existing output names in the root while forwarding these values.

## 3. Preserve an existing database with a moved block

If the root previously managed the database as `aws_db_instance.example`, add this temporary or permanent state-move declaration to that same root:

```hcl
moved {
  from = aws_db_instance.example
  to   = module.mysql.aws_db_instance.example
}
```

Use the actual old resource address if it differs. This changes Terraform's state address without recreating the RDS instance.

If the database was destroyed already, or the root has no existing matching state, do not add a moved block; the module will create a new instance on apply.

## 4. Review before applying

Run these commands from the environment root, not from this modules repository:

```bash
terraform fmt -recursive
terraform init
terraform plan
```

For an existing database, the plan must show a move to `module.mysql.aws_db_instance.example`, not a destroy-and-recreate operation. Apply only after confirming that result. Protect database credentials and commit the root's `.terraform.lock.hcl` when appropriate.
