# MySQL Module Migration

The current MySQL configuration in stage/data-stores/mysql manages an existing RDS instance and stores its state at:

```text
stage/data-stores/mysql/terraform.tfstate
```

Because the database is stateful, preserve the existing RDS instance during this migration. Do not destroy and recreate it.

## 1. Create the module directory

Create:

```text
modules/data-stores/mysql/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tf
```

The reusable module contains the RDS resource, variables, outputs, and required provider declaration. It must not contain a backend or a configured provider block.

## 2. Move the RDS resource into the module

Copy the aws_db_instance.example resource from stage/data-stores/mysql/main.tf into modules/data-stores/mysql/main.tf. Keep the existing settings:

```hcl
resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 20
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "example_database"

  username = var.db_username
  password = var.db_password
}
```

## 3. Define module variables

Create modules/data-stores/mysql/variables.tf:

```hcl
variable "db_username" {
  description = "The username for the database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}
```

Keep stage/data-stores/mysql/variables.tf in the root configuration because the root receives values from vars.sh and passes them to the module.

## 4. Define module outputs

Create modules/data-stores/mysql/outputs.tf:

```hcl
output "address" {
  value       = aws_db_instance.example.address
  description = "Connect to the database at this endpoint"
}

output "port" {
  value       = aws_db_instance.example.port
  description = "The port the database is listening on"
}
```

## 5. Declare the module provider requirement

Create modules/data-stores/mysql/terraform.tf:

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
```

Do not add a configured provider block to the module. Keep the configured provider in stage/data-stores/mysql/providers.tf.

## 6. Replace the root resource with a module call

Replace the contents of stage/data-stores/mysql/main.tf with:

```hcl
module "mysql" {
  source = "../../../modules/data-stores/mysql"

  db_username = var.db_username
  db_password = var.db_password
}
```

Keep these files in stage/data-stores/mysql:

- backend.tf
- providers.tf
- variables.tf
- vars.sh
- .env

Do not move the backend into the module.

## 7. Re-export the module outputs

Replace the contents of stage/data-stores/mysql/outputs.tf with:

```hcl
output "address" {
  value = module.mysql.address
}

output "port" {
  value = module.mysql.port
}
```

The output names must remain address and port because stage/services/webserver-cluster reads those names from MySQL remote state.

## 8. State migration is not required

The previous RDS instance was destroyed before this module migration, so there is no existing RDS resource address to preserve. Do not add a moved block.

Terraform will create a new RDS instance from module.mysql when the configuration is applied.

## 9. Format, initialize, and inspect the plan

From the stage/data-stores/mysql root:

```bash
cd stage/data-stores/mysql
source ./vars.sh
terraform fmt -recursive
terraform init
terraform plan
```

The plan must show the resource moving to module.mysql.aws_db_instance.example. It must not show the RDS instance being destroyed, recreated, or replaced.

## 10. Apply the migration

After confirming the plan:

```bash
terraform apply
```

The MySQL state remains at stage/data-stores/mysql/terraform.tfstate. The root outputs remain address and port, so the webserver configuration can continue reading the database remote-state outputs.

The .env file contains credentials and must remain ignored by Git. Commit the .terraform.lock.hcl file to preserve the selected provider version.
