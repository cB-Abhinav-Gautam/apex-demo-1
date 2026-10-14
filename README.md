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

## Tagging

Every resource carries the `owner` and `environment` tags required by the
`tagging-standard` governance bundle. Override via the `owner`, `environment`
and `additional_tags` variables.

## Usage

```bash
tofu init
tofu plan
```
