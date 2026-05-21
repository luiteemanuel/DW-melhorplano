variable "project" {
  type = string
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket ARN"
}

variable "tags" {
  type = map(string)
}
