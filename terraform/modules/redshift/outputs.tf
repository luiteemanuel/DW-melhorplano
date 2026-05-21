output "endpoint" {
  value = aws_redshift_cluster.main.endpoint
}

output "port" {
  value = aws_redshift_cluster.main.port
}

output "cluster_id" {
  value = aws_redshift_cluster.main.cluster_identifier
}
