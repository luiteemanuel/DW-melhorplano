resource "aws_glue_catalog_database" "main" {
  name = "${replace(var.project, "-", "_")}_db"
}

resource "aws_glue_crawler" "main" {
  name          = "${var.project}-crawler"
  role          = var.glue_role_arn
  database_name = aws_glue_catalog_database.main.name

  s3_target {
    path = "s3://${var.s3_bucket_name}/source/vendas/"
  }

  s3_target {
    path = "s3://${var.s3_bucket_name}/source/clientes/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  tags = var.tags
}

resource "aws_glue_connection" "redshift" {
  name = "${var.project}-redshift-conn"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${var.redshift_endpoint}/${var.redshift_db_name}"
    USERNAME            = var.redshift_username
    PASSWORD            = var.redshift_password
  }

  tags = var.tags
}

resource "aws_glue_job" "etl" {
  name         = "${var.project}-etl-job"
  role_arn     = var.glue_role_arn
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${var.s3_bucket_name}/scripts/etl_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--S3_BUCKET"                        = var.s3_bucket_name
    "--REDSHIFT_JDBC_URL"                = "jdbc:redshift://${var.redshift_endpoint}/${var.redshift_db_name}"
    "--REDSHIFT_USER"                    = var.redshift_username
    "--REDSHIFT_PASSWORD"                = var.redshift_password
    "--DATABASE_NAME"                    = aws_glue_catalog_database.main.name
    "--REDSHIFT_TMP_DIR"                 = "s3://${var.s3_bucket_name}/tmp/"
  }

  connections = [aws_glue_connection.redshift.name]

  worker_type       = "G.1X"
  number_of_workers = 2

  tags = var.tags
}
