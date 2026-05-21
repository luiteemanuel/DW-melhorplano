variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "glue_role_arn" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "redshift_endpoint" {
  type = string
}

variable "redshift_db_name" {
  type = string
}

variable "redshift_username" {
  type = string
}

variable "redshift_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}
