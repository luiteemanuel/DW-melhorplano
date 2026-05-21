output "job_name" {
  value = aws_glue_job.etl.name
}

output "crawler_name" {
  value = aws_glue_crawler.main.name
}

output "catalog_database" {
  value = aws_glue_catalog_database.main.name
}
