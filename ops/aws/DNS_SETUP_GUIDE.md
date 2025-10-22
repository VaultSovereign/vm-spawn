# 🌐 VaultMesh.Cloud DNS Setup Guide

**Quick setup for Aurora production endpoints**

---

## Prerequisites

- AWS Account with Route53 access
- Domain registered: `vaultmesh.cloud`
- `aws` CLI configured
- `terraform` installed (optional, for IaC)

---

## Option A: Terraform (Recommended)

```bash
# Navigate to AWS configs
cd ops/aws

# Initialize Terraform
terraform init

# Review changes
terraform plan -var="aws_account_id=YOUR_ACCOUNT_ID"

# Apply configuration
terraform apply -var="aws_account_id=YOUR_ACCOUNT_ID"

# Expected output:
# - Route53 hosted zone created
# - ACM certificates requested
# - DNS records for api, console, grafana, prometheus
# - CAA, SPF, DMARC records
# - Health checks
```

---

## Option B: AWS CLI (Manual)

### 1. Create Hosted Zone

```bash
aws route53 create-hosted-zone \
  --name vaultmesh.cloud \
  --caller-reference "$(date +%s)"

# Save zone ID
export ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='vaultmesh.cloud.'].Id" --output text)
```

### 2. Request ACM Certificates

**Global (for CloudFront):**
```bash
aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region us-east-1

# Save certificate ARN
export CERT_ARN_GLOBAL=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='*.vaultmesh.cloud'].CertificateArn" --output text)
```

**Regional (for ALB):**
```bash
aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region eu-west-1

# Save certificate ARN
export CERT_ARN_REGIONAL=$(aws acm list-certificates --region eu-west-1 --query "CertificateSummaryList[?DomainName=='*.vaultmesh.cloud'].CertificateArn" --output text)
```

### 3. Add DNS Validation Records

```bash
# Get validation records from ACM
aws acm describe-certificate \
  --certificate-arn $CERT_ARN_REGIONAL \
  --region eu-west-1 \
  --query "Certificate.DomainValidationOptions"

# Create validation records (example)
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "_VALIDATION_NAME.vaultmesh.cloud",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "VALIDATION_VALUE"}]
      }
    }]
  }'
```

### 4. Create Production Records

**API endpoint (will point to ALB after EKS deploy):**
```bash
cat > /tmp/api-record.json <<'JSON'
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "api.vaultmesh.cloud",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z215JYRZR1TBD5",
        "DNSName": "aurora-alb-PLACEHOLDER.eu-west-1.elb.amazonaws.com",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
JSON

# Update PLACEHOLDER with actual ALB DNS after EKS deployment
```

**Grafana (CNAME to K8s LoadBalancer):**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "grafana.vaultmesh.cloud",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "grafana-nlb.eu-west-1.elb.amazonaws.com"}]
      }
    }]
  }'
```

### 5. Add Security Records

**CAA:**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "vaultmesh.cloud",
        "Type": "CAA",
        "TTL": 3600,
        "ResourceRecords": [
          {"Value": "0 issue \"amazon.com\""},
          {"Value": "0 issuewild \"amazon.com\""},
          {"Value": "0 iodef \"mailto:security@vaultmesh.cloud\""}
        ]
      }
    }]
  }'
```

**SPF:**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "vaultmesh.cloud",
        "Type": "TXT",
        "TTL": 3600,
        "ResourceRecords": [{"Value": "\"v=spf1 include:amazonses.com ~all\""}]
      }
    }]
  }'
```

**DMARC:**
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "_dmarc.vaultmesh.cloud",
        "Type": "TXT",
        "TTL": 3600,
        "ResourceRecords": [{"Value": "\"v=DMARC1; p=quarantine; rua=mailto:dmarc@vaultmesh.cloud\""}]
      }
    }]
  }'
```

---

## After EKS Deployment

### Update DNS with Real LoadBalancer Endpoints

```bash
# Get Grafana LoadBalancer hostname
GRAFANA_LB=$(kubectl get svc -n aurora-staging grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Update Grafana CNAME
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"grafana.vaultmesh.cloud\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$GRAFANA_LB\"}]
      }
    }]
  }"

# Repeat for Prometheus
PROMETHEUS_LB=$(kubectl get svc -n aurora-staging prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"prometheus.vaultmesh.cloud\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$PROMETHEUS_LB\"}]
      }
    }]
  }"
```

---

## Verification

```bash
# Check DNS propagation
dig api.vaultmesh.cloud +short
dig grafana.vaultmesh.cloud +short
dig console.vaultmesh.cloud +short

# Verify TLS certificate
openssl s_client -connect api.vaultmesh.cloud:443 -servername api.vaultmesh.cloud < /dev/null

# Test health checks
curl https://api.vaultmesh.cloud/health
curl https://console.vaultmesh.cloud/
```

---

## Update EKS Ingress

### Annotate Ingress Resources

```bash
# Aurora API
kubectl annotate ingress aurora-api -n aurora-staging \
  external-dns.alpha.kubernetes.io/hostname=api.vaultmesh.cloud \
  cert-manager.io/cluster-issuer=letsencrypt-prod

# Aurora Console
kubectl annotate ingress aurora-console -n aurora-staging \
  external-dns.alpha.kubernetes.io/hostname=console.vaultmesh.cloud \
  cert-manager.io/cluster-issuer=letsencrypt-prod

# Grafana
kubectl annotate ingress grafana -n aurora-staging \
  external-dns.alpha.kubernetes.io/hostname=grafana.vaultmesh.cloud \
  cert-manager.io/cluster-issuer=letsencrypt-prod
```

---

## Domain Registrar Configuration

### Update Name Servers

After creating the Route53 hosted zone, update your domain registrar:

```bash
# Get Route53 name servers
aws route53 get-hosted-zone --id $ZONE_ID --query "DelegationSet.NameServers"

# Example output:
# [
#   "ns-123.awsdns-12.com",
#   "ns-456.awsdns-34.net",
#   "ns-789.awsdns-56.org",
#   "ns-012.awsdns-78.co.uk"
# ]

# Update these at your domain registrar (e.g., Namecheap, GoDaddy)
```

---

## Troubleshooting

### DNS not resolving

```bash
# Check name server propagation
dig NS vaultmesh.cloud +trace

# Wait 24-48 hours for full propagation
```

### Certificate validation stuck

```bash
# Check validation records exist
dig _VALIDATION_NAME.vaultmesh.cloud CNAME +short

# Verify certificate status
aws acm describe-certificate --certificate-arn $CERT_ARN_REGIONAL --region eu-west-1
```

### LoadBalancer not accessible

```bash
# Check security groups allow 443
aws ec2 describe-security-groups --filters "Name=tag:kubernetes.io/cluster/aurora-staging,Values=owned"

# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

---

## Cost Estimate

```
Route53 Hosted Zone:     $0.50/month
Health Checks (2):       $1.00/month ($0.50 each)
ACM Certificates:        Free
DNS Queries:             $0.40/million queries
Total baseline:          ~$2/month + query costs
```

---

## Next Steps

1. ✅ Complete DNS setup
2. Deploy EKS cluster with updated domain annotations
3. Verify all endpoints are accessible via vaultmesh.cloud
4. Update documentation and client configs with new endpoints
5. Test full flow: `https://api.vaultmesh.cloud` → EKS → Aurora

---

**Documentation:** [DOMAIN_STRATEGY.md](../../DOMAIN_STRATEGY.md)  
**Terraform Config:** [route53-vaultmesh-cloud.tf](./route53-vaultmesh-cloud.tf)
