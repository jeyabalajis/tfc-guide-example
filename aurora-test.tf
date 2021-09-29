locals {
    name = "dbiusa-casc-cn-aurora-postgres-dev"
    region = "us-east-1"
    tags = {
    ITOwnerEmail    = "ravi_kiranj@cargill.com"
    ApplicationName = "dbiusa-casc-cn-aurora-postgres-dev"
    Environment = "dev"
    Terraform = "true"
    }
}

################################################################################
# Supporting Resources
################################################################################

resource "random_integer" "sequence" {
  min     = 2000
  max     = 9999
}

resource "aws_db_parameter_group" "example" {
  name_prefix = "${local.name}-parameter-group"
  family      = "aurora-postgresql11"
  description = "${local.name}-parameter-group"
  tags        = local.tags
}

resource "aws_rds_cluster_parameter_group" "example" {
  name_prefix = "${local.name}-cluster-parameter-group"
  family      = "aurora-postgresql11"
  description = "${local.name}-cluster-parameter-group"
  tags        = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  tags = local.tags
}

################################################################################
# RDS Aurora Module
################################################################################

module "rds-aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "5.2.0"

  name = "${local.name}${random_integer.sequence.result}"
  engine = "aurora-postgresql"
  engine_version = "11.9"  
  instance_type         = "db.r4.large"
  instance_type_replica = "db.r4.large"
  db_cluster_parameter_group_name = aws_db_parameter_group.example.id
  db_parameter_group_name = aws_rds_cluster_parameter_group.example.id
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  replica_count         = 1
  replica_scale_enabled = true
  replica_scale_min     = 1
  replica_scale_max     = 5

  monitoring_interval           = 60
  iam_role_name                 = "${local.name}-enhanced-monitoring"
  iam_role_use_name_prefix      = true
  iam_role_description          = "${local.name} RDS enhanced monitoring IAM role"
  iam_role_path                 = "/autoscaling/"
  iam_role_max_session_duration = 7200

  apply_immediately   = true
  skip_final_snapshot = true

  allowed_security_groups         = ["sg-12345678"]
  storage_encrypted               = true

  vpc_id                = module.vpc.vpc_id
  db_subnet_group_name  = module.vpc.database_subnet_group_name
  create_security_group = true
  allowed_cidr_blocks   = module.vpc.private_subnets_cidr_blocks
}
