data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "redshift" {
  name        = "${var.project}-redshift-sg"
  description = "Allow Redshift access from Glue"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Redshift port from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project}-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = var.tags
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier        = "${var.project}-${var.environment}"
  database_name             = var.db_name
  master_username           = var.master_username
  master_password           = var.master_password
  node_type                 = "dc2.large"
  cluster_type              = "single-node"
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  publicly_accessible       = false
  skip_final_snapshot       = true
  iam_roles                 = [var.redshift_role_arn]
  tags                      = var.tags
}
