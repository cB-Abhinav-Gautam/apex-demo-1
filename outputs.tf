# --- Networking ------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets hosting the load balancer."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets hosting the Fargate tasks."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = module.vpc.database_subnets
}

output "internet_gateway_id" {
  description = "ID of the internet gateway attached to the VPC."
  value       = module.vpc.igw_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways used for private egress."
  value       = module.vpc.natgw_ids
}

# --- Application -----------------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the accounting load balancer."
  value       = module.alb.dns_name
}

output "accounting_service_url" {
  description = "Base URL of the Fineract CN accounting API."
  value       = "https://${var.domain_name}${var.context_path}/"
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. DNS validation records must be published before the endpoint serves traffic."
  value       = module.acm.acm_certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS records that must be created to validate the ACM certificate."
  value       = module.acm.acm_certificate_domain_validation_options
}

output "ecr_repository_url" {
  description = "ECR repository the accounting image is pushed to."
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running the accounting service."
  value       = module.ecs.cluster_name
}

# --- Data stores -----------------------------------------------------------

output "postgres_endpoint" {
  description = "Connection endpoint of the PostgreSQL instance."
  value       = module.postgresql.db_instance_endpoint
}

output "postgres_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the PostgreSQL master credentials."
  value       = module.postgresql.db_instance_master_user_secret_arn
}

output "keyspace_name" {
  description = "Name of the Amazon Keyspaces keyspace used by Fineract CN."
  value       = aws_keyspaces_keyspace.fineract.name
}

output "mq_broker_endpoints" {
  description = "Wire-level endpoints of the ActiveMQ broker."
  value       = aws_mq_broker.fineract.instances[*].endpoints
}

output "mq_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the ActiveMQ broker credentials."
  value       = aws_secretsmanager_secret.mq.arn
}

output "kms_key_arn" {
  description = "ARN of the customer-managed key encrypting the platform data stores."
  value       = aws_kms_key.main.arn
}

output "alb_logs_bucket" {
  description = "Private S3 bucket receiving load balancer access logs."
  value       = module.alb_logs.s3_bucket_id
}
