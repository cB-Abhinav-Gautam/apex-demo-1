resource "aws_cloudwatch_log_group" "service" {
  name              = "/aws/ecs/${local.service_prefix}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.main.arn

  tags = local.common_tags

  depends_on = [aws_kms_key_policy.main]
}

# ---------------------------------------------------------------------------
# ECS Fargate cluster and the accounting service.
#
# Configuration mirrors service/src/main/resources/application.yml: the
# service listens on var.container_port under var.context_path, talks to
# PostgreSQL ('seshat'), Cassandra/Keyspaces ('seshat') and an ActiveMQ
# broker. Spring Cloud Config and Eureka discovery are disabled until the
# Fineract CN provisioner and identity services are deployed alongside it.
# ---------------------------------------------------------------------------
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"

  cluster_name = local.service_prefix

  cluster_configuration = {
    execute_command_configuration = {
      logging    = "OVERRIDE"
      kms_key_id = aws_kms_key.main.arn

      log_configuration = {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.service.name
      }
    }
  }

  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enabled"
    },
  ]

  # Keep the cluster log group under this stack's control.
  create_cloudwatch_log_group = false

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
        base   = 1
      }
    }
  }

  services = {
    accounting = {
      cpu           = var.task_cpu
      memory        = var.task_memory
      desired_count = var.desired_count

      launch_type = "FARGATE"

      task_exec_iam_role_arn    = aws_iam_role.task_execution.arn
      tasks_iam_role_arn        = aws_iam_role.task.arn
      create_task_exec_iam_role = false
      create_tasks_iam_role     = false

      enable_execute_command = false

      subnet_ids            = module.vpc.private_subnets
      assign_public_ip      = false
      security_group_ids    = [aws_security_group.service.id]
      create_security_group = false

      load_balancer = {
        accounting = {
          target_group_arn = module.alb.target_groups["accounting"].arn
          container_name   = var.service_name
          container_port   = var.container_port
        }
      }

      container_definitions = {
        (var.service_name) = {
          image     = "${module.ecr.repository_url}:${var.image_tag}"
          essential = true

          # The image stores its bootable jar under /tmp, so the root
          # filesystem has to stay writable for this service.
          readonly_root_filesystem = false

          port_mappings = [
            {
              name          = "http"
              containerPort = var.container_port
              hostPort      = var.container_port
              protocol      = "tcp"
            },
          ]

          environment = [
            { name = "SERVER_PORT", value = tostring(var.container_port) },
            { name = "SERVER_MAX_HTTP_HEADER_SIZE", value = "16384" },
            { name = "SPRING_CLOUD_DISCOVERY_ENABLED", value = "false" },
            { name = "SPRING_CLOUD_CONFIG_ENABLED", value = "false" },
            { name = "CASSANDRA_CLUSTERNAME", value = "Amazon Keyspaces" },
            { name = "CASSANDRA_CONTACTPOINTS", value = "cassandra.${var.aws_region}.amazonaws.com:9142" },
            { name = "CASSANDRA_KEYSPACE", value = aws_keyspaces_keyspace.fineract.name },
            { name = "CASSANDRA_CL_READ", value = "LOCAL_QUORUM" },
            { name = "CASSANDRA_CL_WRITE", value = "LOCAL_QUORUM" },
            { name = "CASSANDRA_CL_DELETE", value = "LOCAL_QUORUM" },
            { name = "POSTGRESQL_DRIVERCLASS", value = "org.postgresql.Driver" },
            { name = "POSTGRESQL_HOST", value = module.postgresql.db_instance_address },
            { name = "POSTGRESQL_PORT", value = "5432" },
            { name = "POSTGRESQL_DATABASE", value = var.postgres_database_name },
            { name = "POSTGRESQL_USER", value = var.postgres_username },
            { name = "ACTIVEMQ_BROKERURL", value = tolist(aws_mq_broker.fineract.instances)[0].endpoints[0] },
          ]

          secrets = [
            {
              name      = "POSTGRESQL_PASSWORD"
              valueFrom = "${module.postgresql.db_instance_master_user_secret_arn}:password::"
            },
            {
              name      = "ACTIVEMQ_PASSWORD"
              valueFrom = "${aws_secretsmanager_secret.mq.arn}:password::"
            },
          ]

          enable_cloudwatch_logging = false

          log_configuration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.service.name
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      }

      tags = local.common_tags
    }
  }

  tags = local.common_tags
}
