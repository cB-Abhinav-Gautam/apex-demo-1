# ---------------------------------------------------------------------------
# Access log bucket. Private and encrypted: the mandatory "no-public-storage"
# policy requires public access blocks on and no public ACL or policy.
# ---------------------------------------------------------------------------
module "alb_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = local.alb_logs_bucket_name

  force_destroy = false

  # Public access blocked on every vector.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    status = "Enabled"
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        # Elastic Load Balancing delivers access logs with SSE-S3 only.
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
    }
  }

  # Grants the regional ELB log-delivery principal write access. This is a
  # named AWS service principal, never a wildcard principal.
  attach_elb_log_delivery_policy        = true
  attach_lb_log_delivery_policy         = true
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # Server access logging for the log bucket itself. The target is the
  # literal bucket name so the bucket does not depend on its own output.
  logging = {
    target_bucket = local.alb_logs_bucket_name
    target_prefix = "s3-access-logs/"
  }

  lifecycle_rule = [
    {
      id      = "expire-access-logs"
      enabled = true

      filter = {
        prefix = ""
      }

      noncurrent_version_expiration = {
        noncurrent_days = 90
      }

      expiration = {
        days = 365
      }

      abort_incomplete_multipart_upload_days = 7
    },
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# TLS certificate for the accounting endpoint. DNS validation records are
# created outside this stack, so the apply does not block on validation.
# ---------------------------------------------------------------------------
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.1.1"

  domain_name = var.domain_name

  validation_method      = "DNS"
  create_route53_records = false
  validate_certificate   = false
  wait_for_validation    = false

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Application Load Balancer. HTTPS only; port 80 redirects to 443.
# ---------------------------------------------------------------------------
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.12.0"

  name    = "${local.service_prefix}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  load_balancer_type = "application"
  internal           = false

  # The security groups are declared explicitly in security_groups.tf.
  create_security_group = false
  security_groups       = [aws_security_group.alb.id]

  enable_deletion_protection = true
  drop_invalid_header_fields = true
  enable_http2               = true

  access_logs = {
    bucket  = module.alb_logs.s3_bucket_id
    prefix  = "alb"
    enabled = true
  }

  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn = module.acm.acm_certificate_arn

      forward = {
        target_group_key = "accounting"
      }
    }
  }

  target_groups = {
    accounting = {
      name_prefix       = "acct-"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      deregistration_delay              = 30
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        path                = "${var.context_path}/"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-499"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }

  tags = local.common_tags
}
