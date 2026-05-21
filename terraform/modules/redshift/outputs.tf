output "endpoint" {
  value = aws_redshift_cluster.main.endpoint
}

output "port" {
  value = aws_redshift_cluster.main.port
}

output "cluster_id" {
  value = aws_redshift_cluster.main.cluster_identifier
}

output "security_group_id" {
  value = aws_security_group.redshift.id
}

output "subnet_id" {
  value = tolist(data.aws_subnets.default.ids)[0]
}
