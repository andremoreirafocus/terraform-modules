output "all_users" {
  value = aws_iam_user.example
}
# output "user_arn" {
#   value       = aws_iam_user.example.arn
#   description = "The ARN of the created IAM user"
# }