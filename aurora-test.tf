locals {
    name = "dbiusamea-casc-cn-pg-dev"
    region = "us-east-1"
    vpc_id = "vpc-c6230da2"
    database_subnet_group_name = "dbsgusameaprivate"
    tags = {
    ITOwnerEmail    = "ravi_kiranj@cargill.com"
    ApplicationName = "dbiusamea-casc-cn-aurora-postgres-dev"
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

################################################################################
# RDS Aurora Module
################################################################################

module "rds-aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "5.2.0"

  name                            = "${local.name}${random_integer.sequence.result}"
  engine                          = "aurora-postgresql"
  engine_version                  = "11.9"  
  instance_type                   = "db.r4.large"
  instance_type_replica           = "db.r4.large"
  db_cluster_parameter_group_name = aws_db_parameter_group.example.id
  db_parameter_group_name         = aws_rds_cluster_parameter_group.example.id
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  replica_count         = 1
  replica_scale_enabled = true
  replica_scale_min     = 1
  replica_scale_max     = 5

  monitoring_interval           = 60
  iam_roles                     = ["arn:aws:iam::496395248431:role/rds-monitoring-role"]

  apply_immediately   = true
  skip_final_snapshot = true

  allowed_security_groups         = ["sg-09f82175e1ae28431"]
  storage_encrypted               = true

  vpc_id                = "${local.vpc_id}"
  db_subnet_group_name  = "${local.database_subnet_group_name}"
  create_security_group = true
}
    
# aws_rds_cluster
output "rds_cluster_id" {
  description = "The ID of the cluster"
  value       = module.aurora.rds_cluster_id
}

output "rds_cluster_resource_id" {
  description = "The Resource ID of the cluster"
  value       = module.aurora.rds_cluster_resource_id
}

output "rds_cluster_endpoint" {
  description = "The cluster endpoint"
  value       = module.aurora.rds_cluster_endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = module.aurora.rds_cluster_reader_endpoint
}

output "rds_cluster_database_name" {
  description = "Name for an automatically created database on cluster creation"
  value       = module.aurora.rds_cluster_database_name
}

output "rds_cluster_master_password" {
  description = "The master password"
  value       = module.aurora.rds_cluster_master_password
  sensitive   = true
}

output "rds_cluster_port" {
  description = "The port"
  value       = module.aurora.rds_cluster_port
}

output "rds_cluster_master_username" {
  description = "The master username"
  value       = module.aurora.rds_cluster_master_username
  sensitive   = true
}

# aws_rds_cluster_instance
output "rds_cluster_instance_endpoints" {
  description = "A list of all cluster instance endpoints"
  value       = module.aurora.rds_cluster_instance_endpoints
}

output "rds_cluster_instance_ids" {
  description = "A list of all cluster instance ids"
  value       = module.aurora.rds_cluster_instance_ids
}

# aws_security_group
output "security_group_id" {
  description = "The security group ID of the cluster"
  value       = module.aurora.security_group_id
}

# Enhanced monitoring role
output "enhanced_monitoring_iam_role_name" {
  description = "The name of the enhanced monitoring role"
  value       = module.aurora.enhanced_monitoring_iam_role_name
}

output "enhanced_monitoring_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the enhanced monitoring role"
  value       = module.aurora.enhanced_monitoring_iam_role_arn
}

output "enhanced_monitoring_iam_role_unique_id" {
  description = "Stable and unique string identifying the enhanced monitoring role"
  value       = module.aurora.enhanced_monitoring_iam_role_unique_id
}
