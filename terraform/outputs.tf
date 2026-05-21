output "s3_bucket_name" {
  description = "S3 bucket for source data and Glue scripts"
  value       = module.s3.bucket_name
}

output "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  value       = module.redshift.endpoint
}

output "redshift_port" {
  description = "Redshift cluster port"
  value       = module.redshift.port
}

output "glue_job_name" {
  description = "Glue ETL job name"
  value       = module.glue.job_name
}

output "glue_crawler_name" {
  description = "Glue crawler name"
  value       = module.glue.crawler_name
}
