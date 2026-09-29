output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "DNS name of the ALB"
}

output "ec2_instance_private_ips" {
  description = "Private IP addresses of the running ASG instances"
  value       = data.aws_instances.example.private_ips
}

output "asg_name" {
  value       = aws_autoscaling_group.example.name
  description = "The name of the Auto Scaling Group"
}