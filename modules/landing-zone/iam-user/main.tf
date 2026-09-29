resource "aws_iam_user" "example" {
  for_each = toset(var.user_names)
  name     = each.value
}
# resource "aws_iam_user" "example" {
#   name = var.user_name
# }