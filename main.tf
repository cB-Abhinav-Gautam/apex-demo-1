locals {
  common_tags = merge(
    {
      owner       = var.owner
      environment = var.environment
      managed_by  = "apex"
    },
    var.additional_tags
  )

  # Prefix shared by every resource belonging to the Fineract CN accounting service.
  service_prefix = "${var.name}-${var.service_name}"

  # Computed as a literal (not a module output) so the bucket can reference
  # itself as its own server-access-log target without creating a cycle.
  alb_logs_bucket_name = "${local.service_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# VPC spanning three availability zones with a public tier for the load
# balancer, a private tier for the Fargate tasks and an isolated database
# tier for RDS and Amazon MQ. Built from the approved registry module
# terraform-aws-modules/vpc.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.name
  cidr = var.vpc_cidr

  azs              = var.azs
  public_subnets   = var.public_subnet_cidrs
  private_subnets  = var.private_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # The public subnets stay public for the load balancer, but instances do
  # not receive a public IP automatically; the Fargate tasks run in the
  # private subnets and reach the internet through the NAT gateway.
  map_public_ip_on_launch = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required so private Fargate tasks can pull images from ECR and reach
  # Amazon Keyspaces and Secrets Manager endpoints.
  enable_nat_gateway = true
  single_nat_gateway = true

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

  private_subnet_tags = {
    Tier = "private"
  }

  database_subnet_tags = {
    Tier = "database"
  }

  tags = local.common_tags
}

# Customer-managed key used for every encrypted-at-rest store in the stack:
# RDS storage and Performance Insights, ECR images, Amazon MQ, Secrets
# Manager secrets and CloudWatch log groups.
resource "aws_kms_key" "main" {
  description             = "Customer-managed key for the ${local.service_prefix} platform data stores"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.service_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# CloudWatch Logs writes with the KMS key, so the key policy must allow the
# regional logs service principal to use it.
resource "aws_kms_key_policy" "main" {
  key_id = aws_kms_key.main.key_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
    ]
  })
}
