output "glue_role_arn" {
  value = aws_iam_role.glue.arn
}

output "redshift_role_arn" {
  value = aws_iam_role.redshift.arn
}
