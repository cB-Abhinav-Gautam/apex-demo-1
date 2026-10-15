# ---------------------------------------------------------------------------
# PostgreSQL: the Fineract CN 'seshat' meta database (tenant registry).
# Encrypted at rest with the customer-managed key, private, multi-AZ.
# ---------------------------------------------------------------------------
module "postgresql" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier = "${local.service_prefix}-postgres"

  engine                     = "postgres"
  engine_version             = var.postgres_engine_version
  family                     = var.postgres_family
  major_engine_version       = split(".", var.postgres_engine_version)[0]
  instance_class             = var.postgres_instance_class
  auto_minor_version_upgrade = true

  allocated_storage     = var.postgres_allocated_storage
  max_allocated_storage = var.postgres_max_allocated_storage
  storage_type          = "gp3"

  # Mandatory policy: encryption at rest.
  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  db_name  = var.postgres_database_name
  username = var.postgres_username
  port     = 5432

  # No password in code or state: RDS generates and rotates it in Secrets Manager.
  manage_master_user_password                            = true
  master_user_secret_kms_key_id                          = aws_kms_key.main.arn
  iam_database_authentication_enabled                    = true
  performance_insights_enabled                           = true
  performance_insights_kms_key_id                        = aws_kms_key.main.arn
  performance_insights_retention_period                  = 7
  create_monitoring_role                                 = true
  monitoring_interval                                    = 60
  monitoring_role_name                                   = "${local.service_prefix}-rds-monitoring"
  enabled_cloudwatch_logs_exports                        = ["postgresql", "upgrade"]
  cloudwatch_log_group_retention_in_days                 = var.log_retention_in_days
  cloudwatch_log_group_kms_key_id                        = aws_kms_key.main.arn
  create_cloudwatch_log_group                            = true
  cloudwatch_log_group_skip_destroy                      = false
  cloudwatch_log_group_class                             = "STANDARD"
  manage_master_user_password_rotation                   = false
  master_user_password_rotate_immediately                = false
  master_user_password_rotation_automatically_after_days = 30

  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.database.id]

  backup_retention_period = var.postgres_backup_retention_period
  backup_window           = "03:00-05:00"
  maintenance_window      = "Mon:00:00-Mon:03:00"
  copy_tags_to_snapshot   = true
  deletion_protection     = true
  skip_final_snapshot     = false

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Amazon Keyspaces: the Cassandra-compatible store Fineract CN uses for
# per-tenant ledger and journal data. Tables are created by the Fineract CN
# provisioner at tenant onboarding, so only the keyspace is managed here.
# ---------------------------------------------------------------------------
resource "aws_keyspaces_keyspace" "fineract" {
  name = var.keyspace_name

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Amazon MQ: the ActiveMQ broker the Fineract CN command framework publishes
# domain events to over JMS.
# ---------------------------------------------------------------------------
resource "random_password" "mq" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "mq" {
  name                    = "${local.service_prefix}/mq/broker-credentials"
  description             = "ActiveMQ broker credentials for the Fineract CN command framework"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 30

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "mq" {
  secret_id = aws_secretsmanager_secret.mq.id
  secret_string = jsonencode({
    username = var.mq_username
    password = random_password.mq.result
  })
}

resource "aws_mq_broker" "fineract" {
  broker_name = "${local.service_prefix}-activemq"

  engine_type                = "ActiveMQ"
  engine_version             = var.mq_engine_version
  host_instance_type         = var.mq_host_instance_type
  deployment_mode            = "ACTIVE_STANDBY_MULTI_AZ"
  auto_minor_version_upgrade = true
  publicly_accessible        = false

  subnet_ids      = slice(module.vpc.database_subnets, 0, 2)
  security_groups = [aws_security_group.mq.id]

  encryption_options {
    kms_key_id        = aws_kms_key.main.arn
    use_aws_owned_key = false
  }

  logs {
    general = true
    audit   = true
  }

  maintenance_window_start_time {
    day_of_week = "Monday"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }

  user {
    username = var.mq_username
    password = random_password.mq.result
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECR: registry for the accounting service image built from the repository
# Dockerfile (amazoncorretto:21-alpine, bootable Spring Boot jar).
# ---------------------------------------------------------------------------
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.3.1"

  repository_name = local.service_prefix

  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_kms_key              = aws_kms_key.main.arn
  repository_force_delete         = false

  create_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      },
    ]
  })

  tags = local.common_tags
}
