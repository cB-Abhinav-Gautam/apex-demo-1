variable "aws_region" {
  description = "AWS region to deploy the Fineract CN accounting platform into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to the VPC and all platform resources."
  type        = string
  default     = "apex-demo"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones used for the subnets. Must align with the subnet CIDR lists."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (load balancer tier), one per availability zone."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (ECS application tier), one per availability zone."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for the isolated database subnets (RDS and Amazon MQ), one per availability zone."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "environment" {
  description = "Environment name used for the required 'environment' tag."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owning team or individual used for the required 'owner' tag."
  type        = string
  default     = "platform-engineering"
}

variable "flow_log_retention_in_days" {
  description = "Retention period, in days, for the VPC flow log CloudWatch log group."
  type        = number
  default     = 365
}

variable "log_retention_in_days" {
  description = "Retention period, in days, for application and platform CloudWatch log groups."
  type        = number
  default     = 365
}

variable "additional_tags" {
  description = "Extra tags merged into the required tag set for every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Fineract CN accounting service
# ---------------------------------------------------------------------------

variable "service_name" {
  description = "Logical name of the Fineract CN service deployed by this stack."
  type        = string
  default     = "accounting"
}

variable "container_port" {
  description = "Port the Fineract CN accounting service listens on, as set in the Dockerfile."
  type        = number
  default     = 2025
}

variable "context_path" {
  description = "Servlet context path of the accounting service, used for load balancer health checks."
  type        = string
  default     = "/accounting/v1"
}

variable "image_tag" {
  description = "Container image tag deployed from the ECR repository."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "Fargate task CPU units for the accounting service."
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Fargate task memory, in MiB, for the accounting service."
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of accounting service tasks to run."
  type        = number
  default     = 2
}

variable "domain_name" {
  description = "Fully qualified domain name the accounting service is served on. Used for the ACM certificate."
  type        = string
  default     = "accounting.apex-demo.example.com"
}

# ---------------------------------------------------------------------------
# PostgreSQL (Fineract CN 'seshat' meta database)
# ---------------------------------------------------------------------------

variable "postgres_engine_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "16.4"
}

variable "postgres_family" {
  description = "RDS parameter group family matching postgres_engine_version."
  type        = string
  default     = "postgres16"
}

variable "postgres_instance_class" {
  description = "RDS instance class for the PostgreSQL instance."
  type        = string
  default     = "db.t4g.medium"
}

variable "postgres_allocated_storage" {
  description = "Initial allocated storage, in GiB, for the PostgreSQL instance."
  type        = number
  default     = 50
}

variable "postgres_max_allocated_storage" {
  description = "Upper bound, in GiB, for PostgreSQL storage autoscaling."
  type        = number
  default     = 200
}

variable "postgres_database_name" {
  description = "Initial PostgreSQL database name. Fineract CN expects 'seshat'."
  type        = string
  default     = "seshat"
}

variable "postgres_username" {
  description = "Master username for the PostgreSQL instance."
  type        = string
  default     = "fineract"
}

variable "postgres_backup_retention_period" {
  description = "Number of days to retain automated PostgreSQL backups."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Amazon Keyspaces (Cassandra-compatible store)
# ---------------------------------------------------------------------------

variable "keyspace_name" {
  description = "Cassandra keyspace used by Fineract CN. The application default is 'seshat'."
  type        = string
  default     = "seshat"
}

# ---------------------------------------------------------------------------
# Amazon MQ (ActiveMQ broker for Fineract CN command events)
# ---------------------------------------------------------------------------

variable "mq_engine_version" {
  description = "ActiveMQ engine version for the Amazon MQ broker."
  type        = string
  default     = "5.18"
}

variable "mq_host_instance_type" {
  description = "Amazon MQ broker host instance type."
  type        = string
  default     = "mq.t3.micro"
}

variable "mq_username" {
  description = "ActiveMQ broker username used by the Fineract CN command framework."
  type        = string
  default     = "fineract"
}
