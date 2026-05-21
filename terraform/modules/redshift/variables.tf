variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_name" {
  type = string
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "redshift_role_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}
