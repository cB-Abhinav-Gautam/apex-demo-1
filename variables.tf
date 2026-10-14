variable "aws_region" {
  description = "AWS region to deploy the VPC into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to the VPC and its networking resources."
  type        = string
  default     = "apex-demo"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones used for the subnets. Must align with public_subnet_cidrs."
  type        = list(string)
  default     = ["us-east-1a"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone."
  type        = list(string)
  default     = ["10.0.1.0/24"]
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

variable "additional_tags" {
  description = "Extra tags merged into the required tag set for every resource."
  type        = map(string)
  default     = {}
}
