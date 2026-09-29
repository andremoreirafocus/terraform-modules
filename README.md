# Terraform AWS Tests

This project deploys a MySQL-backed web application in AWS Ohio (`us-east-2`). An Application Load Balancer routes HTTP traffic to EC2 instances in an Auto Scaling group. Terraform manages the database and web application together from one production root configuration and one remote state.

```text
global/s3/                           Creates the S3 backend bucket
modules/data-stores/mysql/           Reusable MySQL RDS module
modules/services/webserver-cluster/  Reusable ALB and Auto Scaling module
prod/                                Production root configuration
```

## Architecture and state

The `prod` root calls both reusable modules. It passes `module.mysql.db_address` and `module.mysql.db_port` directly to the webserver module. Terraform therefore creates the database before creating the launch template that renders those values into `user-data.sh`; no `terraform_remote_state` data source is used.

The production root stores its combined state in this S3 object:

```text
terraform-up-and-running-state-andremoreirafocus/prod/systems/web-app/terraform.tfstate
```

The S3 backend uses server-side encryption and S3 lock files (`use_lockfile = true`). The backend bucket configuration also enables versioning and blocks public access.

## Prerequisites

- Terraform installed
- AWS credentials with access to the backend bucket and permission to create the configured AWS resources
- The backend bucket already created by `global/s3`

Create `prod/.env` locally; it is ignored by Git:

```dotenv
DB_USERNAME=your_database_username
DB_PASSWORD=your_database_password
```

`prod/vars.sh` exports these values as Terraform input variables without printing them.

## Deploy production

Run from the repository root:

```bash
cd prod
source ./vars.sh
terraform fmt -check
terraform init
terraform plan -var="server_port=80"
terraform apply -var="server_port=80"
```

Always review the plan before applying. After a successful apply, retrieve the load balancer address with:

```bash
terraform output -raw alb_dns_name
```

## Existing infrastructure and state migration

The `prod` root is safe to apply as a new deployment. If MySQL or webserver resources were previously created from separate state files, do **not** apply the combined root until their state has been migrated or imported into the combined production state. Otherwise Terraform will not know those resources already exist and can propose duplicates.

When intentionally changing a backend target, use `terraform init -migrate-state` to migrate state. Use `terraform init -reconfigure` only when refreshing Terraform's locally cached backend settings without moving state.

## State locks

Terraform creates an S3 lock object while planning or applying. If a command exits unexpectedly, a stale lock can remain. First confirm that no other Terraform plan, apply, CI job, or terminal is operating on the same state. Then release only the lock ID shown in Terraform's error:

```bash
terraform force-unlock <lock-id>
```

Do not use `-lock=false` for normal operations, and do not force-unlock a lock held by an active operation.

## Repository hygiene

Commit `.terraform.lock.hcl` files so all users select the same provider versions. Do not commit `.env`, `.terraform/`, or `*.tfstate` files.
