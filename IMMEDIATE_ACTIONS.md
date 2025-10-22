# ⚡ Immediate Actions — VaultMesh.Cloud DNS Live

**Status:** Name servers updated, ready for Route53 configuration  
**Timeline:** Next 30 minutes

---

## ✅ What's Done

- [x] vaultmesh.cloud domain registered
- [x] Name servers updated to Route53
- [x] vaultmesh.org preserved (email stays working)

---

## 🚀 Next 3 Steps (30 minutes)

### Step 1: Verify DNS Propagation (5 min)

```bash
# Check if Route53 name servers are responding
dig NS vaultmesh.cloud +short

# Expected: 4 AWS name servers
# ns-123.awsdns-12.com
# ns-456.awsdns-34.net
# ns-789.awsdns-56.org
# ns-012.awsdns-78.co.uk

# If you see these, DNS is propagating ✅
```

**If not showing yet:** Wait 15-30 minutes and try again. DNS propagation can take up to 48 hours but usually 15 minutes - 2 hours.

---

### Step 2: Deploy Route53 DNS Records (10 min)

**Option A — Quick Deploy (Terraform):**

```bash
cd ops/aws

# Create hosted zone first (if not exists)
aws route53 create-hosted-zone \
  --name vaultmesh.cloud \
  --caller-reference "$(date +%s)" \
  --hosted-zone-config Comment="Aurora production domain"

# Get zone ID
export ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='vaultmesh.cloud.'].Id" \
  --output text)

echo "Zone ID: $ZONE_ID"
```

**Request ACM Certificates:**

```bash
# Global certificate (for CloudFront)
export CERT_ARN_GLOBAL=$(aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region us-east-1 \
  --query CertificateArn \
  --output text)

echo "Global Cert: $CERT_ARN_GLOBAL"

# Regional certificate (for ALB)
export CERT_ARN_REGIONAL=$(aws acm request-certificate \
  --domain-name "*.vaultmesh.cloud" \
  --subject-alternative-names "vaultmesh.cloud" \
  --validation-method DNS \
  --region eu-west-1 \
  --query CertificateArn \
  --output text)

echo "Regional Cert: $CERT_ARN_REGIONAL"
```

**Add Certificate Validation Records:**

```bash
# Get validation records for regional cert
aws acm describe-certificate \
  --certificate-arn $CERT_ARN_REGIONAL \
  --region eu-west-1 \
  --query "Certificate.DomainValidationOptions[0].[ResourceRecord.Name,ResourceRecord.Value]" \
  --output text

# Example output:
# _abc123.vaultmesh.cloud    _xyz789.acm-validations.aws

# Add validation CNAME (use actual values from above)
VALIDATION_NAME="<from-above>"
VALIDATION_VALUE="<from-above>"

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"$VALIDATION_NAME\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$VALIDATION_VALUE\"}]
      }
    }]
  }"

# Repeat for global cert (same process, different region)
```

---

### Step 3: Add Security Records (5 min)

**CAA (Certificate Authority Authorization):**

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

**SPF (Email Security):**

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

## ✅ Verification (After Steps 1-3)

```bash
# Check DNS records
dig vaultmesh.cloud CAA +short
dig vaultmesh.cloud TXT +short
dig _dmarc.vaultmesh.cloud TXT +short

# Check certificate status (wait 5-10 min after adding validation records)
aws acm describe-certificate \
  --certificate-arn $CERT_ARN_REGIONAL \
  --region eu-west-1 \
  --query "Certificate.Status"

# Expected: "ISSUED" (may take 5-30 minutes)
```

---

## 🎯 After DNS is Ready (Later Today or Tomorrow)

Once ACM certificates show "ISSUED":

### 1. Deploy EKS Cluster

```bash
eksctl create cluster -f eks-aurora-staging.yaml
# 15-20 minutes
```

### 2. Deploy Aurora to EKS

```bash
kubectl apply -k ops/k8s/overlays/staging-eks
helm install prometheus prometheus-community/prometheus -n aurora-staging -f ops/aws/prometheus-values.yaml
helm install grafana grafana/grafana -n aurora-staging -f ops/aws/grafana-values.yaml
```

### 3. Update DNS with Real LoadBalancer Endpoints

```bash
# Get Grafana LoadBalancer
GRAFANA_LB=$(kubectl get svc -n aurora-staging grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Add CNAME
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"grafana.vaultmesh.cloud\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$GRAFANA_LB\"}]
      }
    }]
  }"

# Repeat for Prometheus, API, etc.
```

### 4. Verify Production Endpoints

```bash
# Test endpoints
curl https://api.vaultmesh.cloud/health
curl https://grafana.vaultmesh.cloud/
curl https://console.vaultmesh.cloud/

# If working: ✅ Week 1 deployment complete!
```

---

## 📊 Timeline

```
Now:              Name servers updated ✅
+15 min:          DNS propagation ✅
+30 min:          Route53 records deployed
+45 min:          ACM certificates issued
+60 min:          Ready for EKS deployment
+80 min:          EKS cluster running
+90 min:          Aurora deployed
+100 min:         DNS updated with real endpoints
+110 min:         https://api.vaultmesh.cloud live! 🚀
```

**Total time:** ~2 hours from now

---

## 🚨 Troubleshooting

### DNS not propagating

```bash
# Force check specific name servers
dig @ns-123.awsdns-12.com vaultmesh.cloud NS

# If working but not globally: just wait, propagation takes time
```

### Certificate stuck in "Pending Validation"

```bash
# Check validation record exists
dig _abc123.vaultmesh.cloud CNAME +short

# If missing: re-add the validation CNAME
# If present: wait 5-30 minutes, ACM checks periodically
```

### EKS deployment fails

```bash
# Check AWS quotas
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# If quota too low: request increase in AWS Console
```

---

## 🎯 Current Focus

**Right now:** Deploy Route53 DNS records (Step 2 above)

**Next:** Wait for ACM certificates to issue (~10-30 min)

**Then:** Deploy EKS with Aurora (WEEK1_EKS_GUIDE.md)

---

## 📞 Quick Reference

- **Check DNS:** `dig vaultmesh.cloud NS +short`
- **Check Cert:** `aws acm describe-certificate --certificate-arn $CERT_ARN_REGIONAL --region eu-west-1`
- **Full EKS Guide:** [WEEK1_EKS_GUIDE.md](../WEEK1_EKS_GUIDE.md)
- **Domain Strategy:** [DOMAIN_STRATEGY.md](../DOMAIN_STRATEGY.md)

---

## 🜂 Status

```
vaultmesh.cloud:  ✅ Name servers updated
Route53:          ⏳ Pending (deploy now)
ACM Certificates: ⏳ Pending (after Route53)
EKS Cluster:      ⏳ Pending (after ACM)
Aurora Launch:    ⏳ Pending (after EKS)

Next Action: Run Step 2 (Deploy Route53 records)
```

**Let's get those DNS records deployed!** 🚀
