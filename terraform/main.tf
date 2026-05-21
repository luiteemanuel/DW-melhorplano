terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project = "mpdw"
  tags = {
    Project     = local.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "s3" {
  source      = "./modules/s3"
  project     = local.project
  environment = var.environment
  tags        = local.tags
}

module "iam" {
  source      = "./modules/iam"
  project     = local.project
  s3_bucket   = module.s3.bucket_arn
  tags        = local.tags
}

module "redshift" {
  source               = "./modules/redshift"
  project              = local.project
  environment          = var.environment
  db_name              = var.redshift_db_name
  master_username      = var.redshift_username
  master_password      = var.redshift_password
  redshift_role_arn    = module.iam.redshift_role_arn
  tags                 = local.tags
}

module "glue" {
  source            = "./modules/glue"
  project           = local.project
  environment       = var.environment
  glue_role_arn     = module.iam.glue_role_arn
  s3_bucket_name    = module.s3.bucket_name
  s3_bucket_arn     = module.s3.bucket_arn
  redshift_endpoint = module.redshift.endpoint
  redshift_db_name  = var.redshift_db_name
  redshift_username = var.redshift_username
  redshift_password = var.redshift_password
  subnet_id         = module.redshift.subnet_id
  security_group_id = module.redshift.security_group_id
  tags              = local.tags
}
