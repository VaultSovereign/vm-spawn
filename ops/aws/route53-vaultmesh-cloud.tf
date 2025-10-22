# Route53 DNS configuration for vaultmesh.cloud
# Production platform domain for Aurora operations

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Hosted Zone (create manually or import existing)
data "aws_route53_zone" "vaultmesh_cloud" {
  name = "vaultmesh.cloud"
}

# ACM Certificate for *.vaultmesh.cloud (us-east-1 for CloudFront)
resource "aws_acm_certificate" "wildcard_cloud_global" {
  provider          = aws.us_east_1
  domain_name       = "*.vaultmesh.cloud"
  validation_method = "DNS"
  
  subject_alternative_names = [
    "vaultmesh.cloud"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "vaultmesh-cloud-wildcard"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ACM Certificate validation records
resource "aws_route53_record" "cert_validation_global" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_cloud_global.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.vaultmesh_cloud.zone_id
}

# ACM Certificate for ALB (regional - eu-west-1)
resource "aws_acm_certificate" "wildcard_cloud_regional" {
  domain_name       = "*.vaultmesh.cloud"
  validation_method = "DNS"
  
  subject_alternative_names = [
    "vaultmesh.cloud"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "vaultmesh-cloud-wildcard-regional"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ============================================================================
# PRODUCTION ENDPOINTS
# ============================================================================

# API Gateway (Aurora API)
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "api.vaultmesh.cloud"
  type    = "A"
  
  alias {
    name                   = aws_lb.aurora_alb.dns_name
    zone_id                = aws_lb.aurora_alb.zone_id
    evaluate_target_health = true
  }
}

# Console UI (CloudFront distribution)
resource "aws_route53_record" "console" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "console.vaultmesh.cloud"
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.console.domain_name
    zone_id                = aws_cloudfront_distribution.console.hosted_zone_id
    evaluate_target_health = false
  }
}

# Grafana (auth-protected)
resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "grafana.vaultmesh.cloud"
  type    = "CNAME"
  ttl     = 300
  records = [
    # Will be set to K8s LoadBalancer hostname after EKS deployment
    "grafana-nlb.eu-west-1.elb.amazonaws.com"
  ]
}

# Prometheus (auth-protected)
resource "aws_route53_record" "prometheus" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "prometheus.vaultmesh.cloud"
  type    = "CNAME"
  ttl     = 300
  records = [
    # Will be set to K8s LoadBalancer hostname after EKS deployment
    "prometheus-nlb.eu-west-1.elb.amazonaws.com"
  ]
}

# Ledger Explorer (read-only receipts)
resource "aws_route53_record" "ledger" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "ledger.vaultmesh.cloud"
  type    = "A"
  
  alias {
    name                   = aws_lb.aurora_alb.dns_name
    zone_id                = aws_lb.aurora_alb.zone_id
    evaluate_target_health = true
  }
}

# Status Page
resource "aws_route53_record" "status" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "status.vaultmesh.cloud"
  type    = "CNAME"
  ttl     = 300
  records = [
    "status-page.cloudflare.com"  # Or custom status page service
  ]
}

# Identity Provider (SSO/OIDC)
resource "aws_route53_record" "idp" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "idp.vaultmesh.cloud"
  type    = "CNAME"
  ttl     = 300
  records = [
    # Cognito, Keycloak, or Okta endpoint
    "cognito-idp.eu-west-1.amazonaws.com"
  ]
}

# Wildcard for tenant workspaces
resource "aws_route53_record" "tenant_wildcard" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "*.tenant.vaultmesh.cloud"
  type    = "A"
  
  alias {
    name                   = aws_lb.aurora_alb.dns_name
    zone_id                = aws_lb.aurora_alb.zone_id
    evaluate_target_health = true
  }
}

# ============================================================================
# SECURITY RECORDS
# ============================================================================

# CAA (Certificate Authority Authorization)
resource "aws_route53_record" "caa" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "vaultmesh.cloud"
  type    = "CAA"
  ttl     = 3600
  
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\"",
    "0 issue \"letsencrypt.org\"",
    "0 iodef \"mailto:security@vaultmesh.cloud\""
  ]
}

# SPF (Sender Policy Framework)
resource "aws_route53_record" "spf" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "vaultmesh.cloud"
  type    = "TXT"
  ttl     = 3600
  
  records = [
    "v=spf1 include:amazonses.com ~all"
  ]
}

# DMARC (Domain-based Message Authentication)
resource "aws_route53_record" "dmarc" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "_dmarc.vaultmesh.cloud"
  type    = "TXT"
  ttl     = 3600
  
  records = [
    "v=DMARC1; p=quarantine; rua=mailto:dmarc@vaultmesh.cloud; ruf=mailto:dmarc@vaultmesh.cloud; fo=1"
  ]
}

# MX Records (SES or workspace email)
resource "aws_route53_record" "mx" {
  zone_id = data.aws_route53_zone.vaultmesh_cloud.zone_id
  name    = "vaultmesh.cloud"
  type    = "MX"
  ttl     = 3600
  
  records = [
    "10 inbound-smtp.eu-west-1.amazonaws.com"
  ]
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

resource "aws_route53_health_check" "api" {
  fqdn              = "api.vaultmesh.cloud"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  
  tags = {
    Name = "aurora-api-health"
  }
}

resource "aws_route53_health_check" "console" {
  fqdn              = "console.vaultmesh.cloud"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
  
  tags = {
    Name = "aurora-console-health"
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.vaultmesh_cloud.zone_id
}

output "name_servers" {
  description = "Name servers for domain registrar"
  value       = data.aws_route53_zone.vaultmesh_cloud.name_servers
}

output "api_endpoint" {
  description = "Aurora API endpoint"
  value       = "https://api.vaultmesh.cloud"
}

output "console_endpoint" {
  description = "Aurora Console endpoint"
  value       = "https://console.vaultmesh.cloud"
}

output "grafana_endpoint" {
  description = "Grafana dashboard endpoint"
  value       = "https://grafana.vaultmesh.cloud"
}
