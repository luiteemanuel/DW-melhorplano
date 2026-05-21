variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "redshift_db_name" {
  description = "Redshift database name"
  type        = string
  default     = "melhorplano"
}

variable "redshift_username" {
  description = "Redshift master username"
  type        = string
  default     = "admin"
}

variable "redshift_password" {
  description = "Redshift master password"
  type        = string
  sensitive   = true
}
