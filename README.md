# Terraform AWS Modules

This repository contains reusable Terraform modules only. It does **not** include environment root configurations, a remote-state backend, AWS provider configuration, credentials, `.env` files, or Terraform state.

```text
modules/
├── data-stores/
│   └── mysql/                 Provisions a MySQL RDS instance
└── services/
    └── webserver-cluster/     Provisions an ALB-backed EC2 Auto Scaling cluster
```

Use these modules from a separate root configuration for each environment (for example, `dev`, `stage`, or `prod`). The consuming root is responsible for its own backend, configured AWS provider, state lifecycle, credentials, and environment-specific values.

## Requirements

- Terraform
- AWS credentials with permissions appropriate for the resources your root configuration manages
- An AWS provider configuration in the consuming root

Both modules declare their AWS provider requirement but deliberately contain no configured `provider` or `backend` blocks. Provider configuration is inherited from the calling root.

## Modules

### MySQL

Source: `modules/data-stores/mysql`

Creates an `aws_db_instance` running MySQL with 20 GiB of storage, the `db.t3.micro` instance class, database name `example_database`, and `skip_final_snapshot = true`.

Inputs:

- `db_username` (string, sensitive)
- `db_password` (string, sensitive)

Outputs:

- `db_address` — RDS endpoint address
- `db_port` — RDS port

### Webserver cluster

Source: `modules/services/webserver-cluster`

Creates an Application Load Balancer, listener, target group, EC2 launch template, Auto Scaling group, and the associated security groups in the default VPC and its default-VPC subnets. Its user-data script starts BusyBox HTTP and renders the database address and port into the response page.

Inputs:

- `server_port` (number)
- `cluster_name` (string)
- `instance_type` (string)
- `min_size` (number)
- `max_size` (number)
- `db_address` (string)
- `db_port` (number)

Outputs:

- `alb_dns_name` — DNS name of the Application Load Balancer
- `ec2_instance_private_ips` — private IPs of running Auto Scaling instances
- `asg_name` — Auto Scaling group name

## Example consumer configuration

In an environment root outside this repository, reference the modules by a relative path (or pin a VCS release when consuming the repository remotely):

```hcl
provider "aws" {
  region = "us-east-2"
}

module "mysql" {
  source = "../terraform-modules/modules/data-stores/mysql"

  db_username = var.db_username
  db_password = var.db_password
}

module "webserver_cluster" {
  source = "../terraform-modules/modules/services/webserver-cluster"

  cluster_name  = "example-webserver"
  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 5
  server_port   = 80
  db_address    = module.mysql.db_address
  db_port       = module.mysql.db_port
}
```

Define the sensitive database inputs in the consuming root and pass them by a secure mechanism such as CI secret variables or `TF_VAR_` environment variables. Do not commit credentials or `.tfstate` files.

## Module development

From this repository root, format and validate the module configurations:

```bash
terraform fmt -check -recursive
terraform init -backend=false modules/data-stores/mysql
terraform validate modules/data-stores/mysql
terraform init -backend=false modules/services/webserver-cluster
terraform validate modules/services/webserver-cluster
```

`terraform validate` checks configuration consistency only; planning or applying requires a consuming root that supplies the provider configuration, module inputs, and state backend.

See [MySQL migration guidance](MYSQL_MODULE_MIGRATION.md) and [webserver cluster migration guidance](WEBSERVER_MODULE_MIGRATION.md) for moving existing root-managed resources into these modules without unintended replacement.
