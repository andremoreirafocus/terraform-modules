# Webserver Cluster Module Migration

The current configuration in `stage/services/webserver-cluster` is a single root configuration. It owns the launch template, Auto Scaling group, EC2 and ALB security groups, load balancer resources, MySQL remote-state lookup, outputs, and the S3 backend state at `stage/services/webserver-cluster/terraform.tfstate`.

The safest migration is to keep the same root directory and state key, then move the application resources into a child module.

## 1. Create the module directory

Create:

```text
modules/services/webserver-cluster/
├── main.tf
├── variables.tf
├── outputs.tf
└── user-data.sh
```

Do not put `backend.tf` or a configured provider in the reusable module. The module describes resources; the environment root configures the backend, provider, and environment-specific values.

## 2. Move the reusable resources into the module

Copy these blocks from the current stage configuration into the module:

- `data.aws_vpc.default`
- `data.aws_subnets.default`
- `aws_launch_template.example`
- `aws_autoscaling_group.example`
- `aws_security_group.instance`
- `data.aws_instances.example`
- `aws_security_group.alb`
- `aws_lb.example`
- `aws_lb_listener.http`
- `aws_lb_target_group.asg`
- `aws_lb_listener_rule.asg`

Keep `user-data.sh` beside the module's `main.tf` and use an explicit path with Base64 encoding:

```hcl
resource "aws_launch_template" "example" {
  image_id               = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = var.db_address
    db_port     = var.db_port
  }))
}
```

The module variables should be:

```hcl
variable "server_port" {
  description = "The port used by the web server"
  type        = number
}

variable "db_address" {
  description = "The database endpoint"
  type        = string
}

variable "db_port" {
  description = "The database port"
  type        = number
}
```

The module should not read MySQL remote state directly. The environment root should read that state and pass the values into the module.

## 3. Keep the provider in the `stage/services/webserver-cluster` root

Keep this in `stage/services/webserver-cluster/providers.tf`:

```hcl
provider "aws" {
  region = "us-east-2"
}
```

The child module inherits this provider. The module must declare the required provider, but must not configure it with a provider block. Write this block in `modules/services/webserver-cluster/terraform.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
```

## 4. Keep the backend in the `stage/services/webserver-cluster` root

Keep `stage/services/webserver-cluster/backend.tf` in the `stage/services/webserver-cluster` root:

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-up-and-running-state-andremoreirafocus"
    key          = "stage/services/webserver-cluster/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

Do not copy this backend into `modules/services/webserver-cluster`.

## 5. Replace stage resources with a module call

After the module files exist, replace the resource blocks in `stage/services/webserver-cluster/main.tf` with:

```hcl
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "terraform-up-and-running-state-andremoreirafocus"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"
  }
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  server_port = var.server_port
  db_address  = data.terraform_remote_state.db.outputs.address
  db_port     = data.terraform_remote_state.db.outputs.port
}
```

Keep `server_port` in `stage/services/webserver-cluster/variables.tf`.

After adding the module call, remove the old implementation from the `stage/services/webserver-cluster` root:

- Remove all resource and data blocks from `stage/services/webserver-cluster/main.tf`.
- Keep only the MySQL `terraform_remote_state` data source and the `module "webserver_cluster"` call in that file.
- Remove `stage/services/webserver-cluster/user-data.sh`; the script now lives at `modules/services/webserver-cluster/user-data.sh`.
- Keep `stage/services/webserver-cluster/backend.tf`, `stage/services/webserver-cluster/providers.tf`, and `stage/services/webserver-cluster/variables.tf`.


## 6. Re-export module outputs

The module's `outputs.tf` should contain:

```hcl
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.example.dns_name
}

output "ec2_instance_private_ips" {
  description = "Private IP addresses of the running ASG instances"
  value       = data.aws_instances.example.private_ips
}
```

`stage/services/webserver-cluster/outputs.tf` must expose them:

```hcl
output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}

output "ec2_instance_private_ips" {
  value = module.webserver_cluster.ec2_instance_private_ips
}
```

## 7. State migration is not required for this project

All previous webserver-cluster resources and their state were destroyed before this module migration. Therefore, Terraform does not need moved blocks. The module resources will be created as new resources under the existing stage/services/webserver-cluster state key.

If resources already existed in the state, moved blocks would be required to preserve them when their addresses changed.

## 8. Initialize and inspect the plan

Before initializing or applying the webserver configuration, create the database from the separate MySQL configuration so its remote-state outputs exist:

```bash
cd stage/data-stores/mysql
source ./vars.sh
terraform init
terraform apply
```

Return to the project root, then initialize and plan the webserver configuration:

From the `stage/services/webserver-cluster` root:

```bash
cd stage/services/webserver-cluster
terraform fmt -recursive
terraform init
terraform plan -var="server_port=80"
```

The plan should show resources moving into the module, with no destroy-and-recreate actions. Do not apply if the plan contains `destroy`, `create`, or `-/+` for the ALB, target group, Auto Scaling group, launch template, or security groups.

## 9. Apply after the plan is safe

```bash
terraform apply -var="server_port=80"
```

Then verify:

```bash
terraform output alb_dns_name
terraform output ec2_instance_private_ips
```

## 10. Add production separately

The production root should have its own provider, backend, variables, module call, and outputs. Use a different state key, such as:

```hcl
key = "prod/services/webserver-cluster/terraform.tfstate"
```

Do not reuse the staging state key. Both environments can call the same module with different inputs and state.
