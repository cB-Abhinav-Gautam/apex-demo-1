locals {
  common_tags = merge(
    {
      owner       = var.owner
      environment = var.environment
      managed_by  = "apex"
    },
    var.additional_tags
  )
}

# VPC with a public subnet (internet gateway + public route table),
# built from the approved registry module terraform-aws-modules/vpc.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name
  cidr = var.vpc_cidr

  azs            = var.azs
  public_subnets = var.public_subnet_cidrs

  # Public subnet: instances launched here receive a public IP.
  map_public_ip_on_launch = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # No private subnets yet, so no NAT gateway is required.
  enable_nat_gateway = false
  single_nat_gateway = false

  # Lock the default security group down to no ingress and no egress.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Flow logs for network traffic auditing.
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_in_days

  public_subnet_tags = {
    Tier = "public"
  }

  tags = local.common_tags
}
