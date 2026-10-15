# Tiered security groups: internet -> ALB -> Fargate tasks -> data stores.
# No rule exposes an administrative port (22/3389), and no rule allows
# egress on all ports to the internet.

resource "aws_security_group" "alb" {
  name        = "${local.service_prefix}-alb"
  description = "Public entry point for the Fineract CN accounting load balancer"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.service_prefix}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests to the accounting service tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.service.id

  tags = local.common_tags
}

resource "aws_security_group" "service" {
  name        = "${local.service_prefix}-service"
  description = "Fineract CN accounting Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.service_prefix}-service" })
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  description                  = "Accounting HTTP traffic from the load balancer only"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "service_https" {
  security_group_id = aws_security_group.service.id
  description       = "TLS egress for ECR, Secrets Manager, KMS and CloudWatch"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "service_keyspaces" {
  security_group_id = aws_security_group.service.id
  description       = "CQL over TLS to Amazon Keyspaces"
  ip_protocol       = "tcp"
  from_port         = 9142
  to_port           = 9142
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "service_to_postgres" {
  security_group_id            = aws_security_group.service.id
  description                  = "PostgreSQL to the seshat meta database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.database.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "service_to_mq" {
  security_group_id            = aws_security_group.service.id
  description                  = "OpenWire over TLS to the ActiveMQ broker"
  ip_protocol                  = "tcp"
  from_port                    = 61617
  to_port                      = 61617
  referenced_security_group_id = aws_security_group.mq.id

  tags = local.common_tags
}

resource "aws_security_group" "database" {
  name        = "${local.service_prefix}-database"
  description = "PostgreSQL instance backing the Fineract CN seshat database"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.service_prefix}-database" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_service" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL from the accounting service tasks only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.service.id

  tags = local.common_tags
}

resource "aws_security_group" "mq" {
  name        = "${local.service_prefix}-mq"
  description = "Amazon MQ ActiveMQ broker for Fineract CN command events"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.service_prefix}-mq" })
}

resource "aws_vpc_security_group_ingress_rule" "mq_from_service" {
  security_group_id            = aws_security_group.mq.id
  description                  = "OpenWire over TLS from the accounting service tasks only"
  ip_protocol                  = "tcp"
  from_port                    = 61617
  to_port                      = 61617
  referenced_security_group_id = aws_security_group.service.id

  tags = local.common_tags
}
