# Aurora EKS Deployment Quickstart

**Target:** Deploy Aurora to AWS EKS with vaultmesh.cloud DNS in **< 30 minutes**

**Status:** Ready to execute
**Prerequisites:** AWS account, ACM certificate, Route53 hosted zone

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] kubectl installed (`brew install kubectl` or `apt install kubectl`)
- [ ] eksctl installed (`brew install eksctl` or [download](https://eksctl.io))
- [ ] Helm 3 installed (`brew install helm` or [download](https://helm.sh))
- [ ] jq installed (`brew install jq` or `apt install jq`)
- [ ] AWS Account ID known
- [ ] ACM certificate ARN (regional, eu-west-1)
- [ ] Route53 hosted zone ID for vaultmesh.cloud

---

## Environment Setup

```bash
# Set your AWS configuration
export AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"          # Replace with your AWS account
export AWS_REGION="eu-west-1"                    # Or your preferred region
export HOSTED_ZONE_ID="Z100505526F6RJ21G6IU4"   # Your Route53 zone ID
export ACM_REGIONAL_ARN="arn:aws:acm:eu-west-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERT_ID"

# Optional: Skip certain steps if already completed
export SKIP_CLUSTER_CREATE=false
export SKIP_ALB_CONTROLLER=false
export SKIP_MONITORING=false
export SKIP_DNS=false

# Optional: Use ExternalDNS for automatic DNS management
export USE_EXTERNAL_DNS=false
```

---

## Quick Deploy (One Command)

```bash
cd ops/aws
./deploy-aurora-eks.sh
```

This script will:
1. ✅ Create EKS cluster (CPU + GPU node pools)
2. ✅ Install AWS Load Balancer Controller
3. ✅ Deploy Aurora staging overlay
4. ✅ Install Prometheus + Grafana
5. ✅ Configure DNS (Route53 alias records)
6. ✅ Verify deployment

**Estimated time:** 20-25 minutes

---

## Step-by-Step Deployment

If you prefer manual control or need to debug, follow these steps:

### Step 1: Create EKS Cluster (10 min)

```bash
cd /home/sovereign/vm-spawn

# Create cluster
eksctl create cluster -f eks-aurora-staging.yaml

# Update kubeconfig
aws eks update-kubeconfig --name aurora-staging --region eu-west-1

# Verify nodes
kubectl get nodes

# Install NVIDIA device plugin for GPU nodes
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml
```

### Step 2: Install AWS Load Balancer Controller (5 min)

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get VPC ID
export VPC_ID=$(aws eks describe-cluster --name aurora-staging --region eu-west-1 \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster aurora-staging --region eu-west-1 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --override-existing-serviceaccounts --approve

# Install ALB controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=aurora-staging \
  --set region=eu-west-1 \
  --set vpcId=$VPC_ID \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Wait for deployment
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

### Step 3: Deploy Aurora Staging (3 min)

```bash
# Update ACM ARN in ingress manifests
cd ops/k8s/overlays/staging-eks
sed -i "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" ingress-*.yaml

# Apply Kustomize overlay
kubectl apply -k .

# Wait for deployments
kubectl -n aurora-staging wait --for=condition=available --timeout=5m deployment --all

# Check status
kubectl -n aurora-staging get deploy,svc,ingress
```

### Step 4: Install Monitoring (5 min)

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm upgrade --install prometheus prometheus-community/prometheus \
  -n aurora-staging --wait

# Install Grafana
helm upgrade --install grafana grafana/grafana \
  -n aurora-staging --wait

# Get Grafana admin password
kubectl get secret --namespace aurora-staging grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""
```

### Step 5: Configure DNS (2 min)

Wait for ALB to be provisioned:

```bash
# Get ALB DNS name
export API_ALB_DNS=$(kubectl -n aurora-staging get ing aurora-api \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "ALB DNS: $API_ALB_DNS"

# Create Route53 alias record
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"api.vaultmesh.cloud\",
        \"Type\": \"A\",
        \"AliasTarget\": {
          \"HostedZoneId\": \"Z32O12XQLNTSW2\",
          \"DNSName\": \"dualstack.${API_ALB_DNS}\",
          \"EvaluateTargetHealth\": false
        }
      }
    }]
  }"

# Repeat for Grafana if desired
export GRAFANA_ALB_DNS=$(kubectl -n aurora-staging get ing aurora-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"grafana.vaultmesh.cloud\",
        \"Type\": \"A\",
        \"AliasTarget\": {
          \"HostedZoneId\": \"Z32O12XQLNTSW2\",
          \"DNSName\": \"dualstack.${GRAFANA_ALB_DNS}\",
          \"EvaluateTargetHealth\": false
        }
      }
    }]
  }"
```

### Step 6: Verify Deployment (2 min)

```bash
cd ops/aws
./verify-aurora-week1.sh
```

---

## Verification Checklist

After deployment, verify:

- [ ] **DNS resolves:** `dig +short api.vaultmesh.cloud`
- [ ] **HTTPS works:** `curl https://api.vaultmesh.cloud/health`
- [ ] **TLS cert valid:** No browser warnings
- [ ] **Grafana accessible:** `https://grafana.vaultmesh.cloud`
- [ ] **Pods running:** `kubectl -n aurora-staging get pods`
- [ ] **Metrics flowing:** Check Grafana dashboards

---

## Endpoints

After successful deployment:

| Service | URL | Notes |
|---------|-----|-------|
| **Aurora API** | https://api.vaultmesh.cloud | Public HTTPS with ACM cert |
| **Grafana** | https://grafana.vaultmesh.cloud | Public HTTPS (consider IP allowlist) |
| **Prometheus** | http://prometheus.aurora-staging.internal | VPC-only (internal ALB) |

---

## Import Grafana Dashboard

```bash
# Get Grafana admin password
kubectl get secret --namespace aurora-staging grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""

# Port-forward to Grafana
kubectl -n aurora-staging port-forward svc/grafana 3000:80

# Open browser to http://localhost:3000
# Login: admin / <password from above>

# Import dashboard: ops/grafana/grafana-kpi-panels-patch.json
```

Or use API:

```bash
export GRAFANA_API_TOKEN="YOUR_TOKEN"

curl -X POST "https://grafana.vaultmesh.cloud/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
  -d @ops/grafana/grafana-kpi-panels-patch.json
```

---

## Week 1 Deliverables

After 72h soak period:

1. **Generate SLO Report**
   ```bash
   make slo-report
   # Creates: canary_slo_report.json with real metrics
   ```

2. **Capture Grafana Screenshot**
   ```bash
   # Navigate to Grafana → Aurora KPI Dashboard
   # Screenshot showing 72h metrics
   # Save as: docs/aurora-staging-metrics-eks.png
   ```

3. **Create Ledger Snapshot**
   ```bash
   # Create snapshot
   ops/bin/remembrancer snapshot create

   # Sign it
   ops/bin/remembrancer sign ops/ledger/snapshots/$(date +%Y%m%d)-eks.json

   # Upload to S3
   aws s3 cp ops/ledger/snapshots/$(date +%Y%m%d)-eks.json.gz \
     s3://aurora-staging-ledger/snapshots/
   ```

4. **Update Handoff Document**
   ```bash
   # Mark Week 1 tasks complete in:
   # AURORA_GA_HANDOFF_COMPLETE.md
   ```

---

## Troubleshooting

### ALB not provisioning

```bash
# Check ALB controller logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress events
kubectl -n aurora-staging describe ing aurora-api
```

### DNS not resolving

```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name=='api.vaultmesh.cloud.']"

# Wait for propagation (can take 1-5 minutes)
watch -n 5 dig +short api.vaultmesh.cloud
```

### Pods not starting

```bash
# Check pod status
kubectl -n aurora-staging get pods

# Check pod logs
kubectl -n aurora-staging logs <pod-name>

# Check events
kubectl -n aurora-staging get events --sort-by='.lastTimestamp'
```

### TLS certificate issues

```bash
# Check ALB listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, 'aurora-api')].LoadBalancerArn" \
    --output text)

# Verify ACM certificate status
aws acm describe-certificate \
  --certificate-arn "$ACM_REGIONAL_ARN" \
  --region "$AWS_REGION"
```

---

## Cost Optimization

### Scale down GPU nodes when idle

```bash
# Scale to zero
eksctl scale nodegroup --cluster aurora-staging \
  --name gpu-pool --nodes 0 --nodes-min 0

# Scale back up
eksctl scale nodegroup --cluster aurora-staging \
  --name gpu-pool --nodes 2 --nodes-min 0
```

### Delete cluster when done

```bash
# Delete all resources
kubectl delete namespace aurora-staging

# Delete cluster
eksctl delete cluster --name aurora-staging --region eu-west-1
```

**Estimated costs:**
- **Week 1 (72h soak):** ~$125-150
- **Monthly (if left running):** ~$2,500-3,000
  - EKS control plane: $73/mo
  - m6i.large × 3: ~$370/mo
  - g5.2xlarge × 2: ~$2,000/mo
  - Data transfer, ALB: ~$50/mo

---

## Security Hardening (Production)

Before production deployment:

1. **Enable private endpoints:**
   ```yaml
   # In eks-aurora-staging.yaml
   vpc:
     clusterEndpoints:
       publicAccess: false
       privateAccess: true
   ```

2. **Add WAF to ALB:**
   ```bash
   # Create WAF WebACL, then add to ingress:
   # alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:...
   ```

3. **Restrict Grafana access:**
   ```yaml
   # In ingress-grafana.yaml
   annotations:
     alb.ingress.kubernetes.io/inbound-cidrs: YOUR_IP/32
   ```

4. **Enable encryption:**
   - EKS secrets encryption (KMS)
   - EBS volume encryption
   - S3 bucket encryption (SSE-KMS)

5. **Network policies:**
   - Already configured in `ops/k8s/overlays/staging/networkpolicy.yaml`
   - Review and tighten as needed

---

## Next Steps

After successful Week 1 deployment:

1. **Week 2:** Canary deployment (10% traffic split)
2. **Week 3:** Production rollout (100% traffic)
3. **Week 4:** Optimization and governance review

See [AURORA_GA_HANDOFF_COMPLETE.md](../../AURORA_GA_HANDOFF_COMPLETE.md) for full roadmap.

---

## Support

**Documentation:**
- [Aurora GA Announcement](../../AURORA_GA_ANNOUNCEMENT.md)
- [Staging → Canary Quickstart](../../AURORA_STAGING_CANARY_QUICKSTART.md)
- [Compliance Annex](../../AURORA_GA_COMPLIANCE_ANNEX.md)

**Verification:**
```bash
# Health check
./ops/aws/verify-aurora-week1.sh

# System status
./ops/bin/health-check

# Cluster info
kubectl cluster-info
```

**Emergency:**
- Rollback: `kubectl delete -k ops/k8s/overlays/staging-eks`
- Scale down: `eksctl scale nodegroup --nodes 0`
- Delete cluster: `eksctl delete cluster --name aurora-staging`

---

**Status:** ✅ Ready to deploy
**Target:** 9.65/10 after Week 1 completion
**Timeline:** 30 min deploy + 72h soak + verification

🚀 **Ready? Run: `./deploy-aurora-eks.sh`**
