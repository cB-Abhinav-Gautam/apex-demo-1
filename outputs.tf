output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "public_subnet_cidr_blocks" {
  description = "CIDR blocks of the public subnets."
  value       = module.vpc.public_subnets_cidr_blocks
}

output "internet_gateway_id" {
  description = "ID of the internet gateway attached to the VPC."
  value       = module.vpc.igw_id
}

output "public_route_table_ids" {
  description = "IDs of the public route tables."
  value       = module.vpc.public_route_table_ids
}
