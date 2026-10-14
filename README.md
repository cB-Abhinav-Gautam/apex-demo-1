# apex-demo-1

Infrastructure for the `apex-demo-stack` Apex stack.

## Contents

| File | Purpose |
| --- | --- |
| `main.tf` | VPC with a public subnet, internet gateway and flow logs |
| `variables.tf` | Configurable inputs (region, CIDRs, AZs, tags) |
| `outputs.tf` | VPC / subnet / gateway identifiers |
| `providers.tf` | AWS provider with default tags |
| `versions.tf` | Terraform and provider version constraints |

## What gets created

- A VPC (`10.0.0.0/16` by default) with DNS support and hostnames enabled.
- One public subnet (`10.0.1.0/24` in `us-east-1a` by default), with an
  internet gateway and a public route table.
- VPC flow logs delivered to a CloudWatch log group.
- The default security group locked down to no ingress and no egress.

## Public IP addressing

The subnet is public — it routes `0.0.0.0/0` to the internet gateway — but
`map_public_ip_on_launch` is set to `false`. Auto-assigning public IPs to every
instance in the subnet trips trivy `AWS-0164` (HIGH) and the stack pipeline's
`scan` stage fails on it.

Workloads that genuinely need inbound internet access should opt in explicitly:

- set `associate_public_ip_address = true` on the specific instance or ENI, or
- attach an Elastic IP, or
- place an ALB/NLB in the public subnet and keep the workload private.

## Tagging

Every resource carries the `owner` and `environment` tags required by the
`tagging-standard` governance bundle. Override via the `owner`, `environment`
and `additional_tags` variables.

## Usage

```bash
tofu init
tofu plan
```
