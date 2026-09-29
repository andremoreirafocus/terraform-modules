# Migrating a Webserver Root Configuration to This Module

This repository supplies only `modules/services/webserver-cluster`; it does not include environment roots, remote-state configuration, providers, or Terraform state. Make these changes in the separate repository that owns the current webserver resources and their state.

The module provisions an ALB, listener, target group, launch template, Auto Scaling group, and security groups. It expects database connection values to be passed in by the calling root; it never reads another Terraform state directly.

## 1. Keep root-only concerns in the consumer

Leave the AWS provider, backend, remote-state data sources, variables, and environment-specific settings in the root configuration. The child module inherits the root's AWS provider and must not contain a configured provider or backend.

## 2. Add the module call

Replace the root's webserver resource and data blocks with a module call. If your root reads database state, keep that data source in the root and pass its outputs to the module.

```hcl
module "webserver_cluster" {
  source = "../terraform-modules/modules/services/webserver-cluster"

  cluster_name  = var.cluster_name
  instance_type = var.instance_type
  min_size      = var.min_size
  max_size      = var.max_size
  server_port   = var.server_port
  db_address    = module.mysql.db_address
  db_port       = module.mysql.db_port
}
```

Adjust `source` to your checkout layout, or use a pinned VCS source. When the database is managed from a separate state, replace the two `module.mysql` expressions with the appropriate root-level remote-state outputs.

Re-export module outputs from the root if users or downstream configurations consume them:

```hcl
output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}

output "ec2_instance_private_ips" {
  value = module.webserver_cluster.ec2_instance_private_ips
}

output "asg_name" {
  value = module.webserver_cluster.asg_name
}
```

## 3. Preserve existing resources with moved blocks

Changing a resource into a child module changes its state address. For an existing deployment, add `moved` blocks in the consuming root for every resource and data source whose address moves. For example:

```hcl
moved {
  from = aws_lb.example
  to   = module.webserver_cluster.aws_lb.example
}

moved {
  from = aws_autoscaling_group.example
  to   = module.webserver_cluster.aws_autoscaling_group.example
}
```

Add equivalent mappings for the launch template, target group, listener, listener rule, security groups, and relevant data sources. Use the exact former addresses from the root's state. If no matching resources exist in state, omit the moved blocks and expect the module to create new resources.

## 4. Review before applying

Run from the environment root:

```bash
terraform fmt -recursive
terraform init
terraform plan
```

For an existing deployment, confirm that Terraform reports state moves and does not propose replacement of the ALB, target group, Auto Scaling group, launch template, or security groups. Apply only after reviewing the plan.

The module uses the default VPC and its default-VPC subnets, and the supplied AMI and instance type must be available in the AWS region selected by the consuming root.
