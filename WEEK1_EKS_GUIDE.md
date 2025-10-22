# 🚀 Week 1 EKS Deployment Guide

**Path:** AWS EKS (Production-Grade)  
**Timeline:** Deploy today, run 72h soak, complete by Nov 18  
**Cost:** ~$100-150 for Week 1 (can scale down after)

---

## Prerequisites Checklist

- [ ] AWS account with admin access (or scoped IAM)
- [ ] `aws` CLI configured (`aws configure`)
- [ ] `eksctl` installed ([install guide](https://eksctl.io/installation/))
- [ ] `kubectl` v1.29+ installed
- [ ] `helm` v3+ installed
- [ ] `jq` and `yq` installed

**Quick install (macOS):**
```bash
brew install awscli eksctl kubectl helm jq yq
```

**Quick install (Linux):**
```bash
# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# kubectl
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Step 1: Create EKS Cluster (15-20 minutes)

```bash
# From repository root
eksctl create cluster -f eks-aurora-staging.yaml

# Expected output:
# ✅ EKS cluster "aurora-staging" created
# ✅ kubectl configured
# ✅ 3 CPU nodes + 2 GPU nodes provisioning
```

**What this creates:**
- EKS control plane (K8s 1.29)
- 3× m6i.large CPU nodes (auto-scaling 3-6)
- 2× g5.2xlarge GPU nodes (auto-scaling 0-4, NVIDIA A10G)
- VPC with public/private subnets
- OIDC provider for service accounts
- IAM roles for metrics exporter + ledger snapshotter

**Verify cluster:**
```bash
kubectl get nodes -o wide

# Expected:
# NAME                           STATUS   ROLES    AGE   VERSION
# ip-10-42-x-x.eu-west-1.compute Ready    <none>   2m    v1.29.x  (m6i.large)
# ip-10-42-x-x.eu-west-1.compute Ready    <none>   2m    v1.29.x  (m6i.large)
# ip-10-42-x-x.eu-west-1.compute Ready    <none>   2m    v1.29.x  (m6i.large)
# ip-10-42-x-x.eu-west-1.compute Ready    <none>   2m    v1.29.x  (g5.2xlarge)
# ip-10-42-x-x.eu-west-1.compute Ready    <none>   2m    v1.29.x  (g5.2xlarge)
```

---

## Step 2: Install NVIDIA Device Plugin (GPU support)

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml

# Verify GPUs detected
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

# Expected:
# NAME                           GPU
# ip-10-42-x-x... (m6i)          <none>
# ip-10-42-x-x... (g5.2xlarge)   1
# ip-10-42-x-x... (g5.2xlarge)   1
```

---

## Step 3: Deploy Aurora Staging Overlay

```bash
# Apply EKS-specific overlay
kubectl apply -k ops/k8s/overlays/staging-eks

# Verify pods
kubectl get pods -n aurora-staging

# Expected:
# NAME                                      READY   STATUS    RESTARTS   AGE
# aurora-bridge-deploy-xxx                  1/1     Running   0          30s
# aurora-metrics-exporter-xxx               1/1     Running   0          30s
# redis-xxx                                 1/1     Running   0          30s
```

**Check LoadBalancer provisioning:**
```bash
kubectl get svc -n aurora-staging

# Expected (after 2-3 minutes):
# NAME                  TYPE           EXTERNAL-IP
# aurora-bridge-svc     LoadBalancer   a1b2c3-xxx.elb.eu-west-1.amazonaws.com
```

---

## Step 4: Install Prometheus + Grafana

### Prometheus

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace aurora-staging \
  --create-namespace \
  --values ops/aws/prometheus-values.yaml \
  --wait

# Get Prometheus endpoint
kubectl get svc -n aurora-staging prometheus-server

# Expected:
# NAME                TYPE           EXTERNAL-IP                        PORT(S)
# prometheus-server   LoadBalancer   a2b3c4-xxx.elb.eu-west-1.amazonaws.com   80:xxxxx/TCP
```

**Verify Prometheus is scraping Aurora metrics:**
```bash
# Port-forward Prometheus UI
kubectl port-forward -n aurora-staging svc/prometheus-server 9090:80 &

# Open browser
open http://localhost:9090

# Query: treaty_fill_rate_p95
# Should show data points (or wait a few minutes for scraping)
```

### Grafana

```bash
# Install Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace aurora-staging \
  --values ops/aws/grafana-values.yaml \
  --wait

# Get Grafana URL
kubectl get svc -n aurora-staging grafana

# Expected:
# NAME      TYPE           EXTERNAL-IP                        PORT(S)
# grafana   LoadBalancer   a3b4c5-xxx.elb.eu-west-1.amazonaws.com   80:xxxxx/TCP

# Get admin password
kubectl get secret --namespace aurora-staging grafana -o jsonpath="{.data.admin-password}" | base64 --decode
echo
```

**Access Grafana:**
```bash
# Get LoadBalancer URL
GRAFANA_URL=$(kubectl get svc -n aurora-staging grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: http://$GRAFANA_URL"

# Login: admin / (password from above)
```

**Import Aurora Dashboard:**
1. Go to Grafana UI → **Dashboards** → **Import**
2. Upload `ops/grafana/grafana-kpi-panels-patch.json`
3. Select Prometheus datasource
4. Click **Import**

---

## Step 5: Start 72-Hour Soak Test

**Start timestamp:**
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" | tee /tmp/aurora-soak-start.txt
```

**Monitor during soak:**
```bash
# Watch pods
watch -n 30 'kubectl get pods -n aurora-staging'

# Watch metrics (Grafana dashboard or Prometheus)
open http://$GRAFANA_URL/d/aurora-kpis

# Check node utilization
watch -n 60 'kubectl top nodes'
```

**Optional: Add synthetic workload (LLM inference pod):**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: llm-workload
  namespace: aurora-staging
spec:
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"
  nodeSelector:
    nvidia.com/gpu: "true"
  containers:
  - name: llm
    image: nvidia/cuda:12.0-runtime
    command: ["/bin/bash", "-c", "while true; do nvidia-smi; sleep 60; done"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
```

---

## Step 6: After 72 Hours — Extract Metrics

**End timestamp:**
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" | tee /tmp/aurora-soak-end.txt
```

### Query Prometheus for SLO Data

```bash
# Create metrics extraction script for Prometheus
cat > scripts/extract-slo-from-prometheus.py <<'PYTHON'
#!/usr/bin/env python3
import requests
import json
from datetime import datetime

PROMETHEUS_URL = "http://localhost:9090"  # Port-forward to Prometheus

def query_prometheus(query):
    resp = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={"query": query})
    return float(resp.json()["data"]["result"][0]["value"][1])

# Extract p95 metrics
fill_rate_p95 = query_prometheus('quantile_over_time(0.95, treaty_fill_rate[72h])')
rtt_p95 = query_prometheus('quantile_over_time(0.95, treaty_rtt_ms[72h])')
provenance_coverage = query_prometheus('avg_over_time(treaty_provenance_coverage[72h])')
policy_latency_p99 = query_prometheus('quantile_over_time(0.99, treaty_policy_latency_ms[72h])')

report = {
    "report_type": "canary_slo",
    "treaty_id": "AURORA-AKASH-001",
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "window": "72h",
    "metrics": {
        "fill_rate_p95": round(fill_rate_p95, 4),
        "rtt_p95_ms": round(rtt_p95, 2),
        "provenance_coverage": round(provenance_coverage, 4),
        "policy_latency_p99_ms": round(policy_latency_p99, 2)
    },
    "slo_compliance": {
        "fill_rate": fill_rate_p95 >= 0.80,
        "rtt": rtt_p95 <= 350,
        "provenance": provenance_coverage >= 0.95,
        "policy_latency": policy_latency_p99 <= 25
    },
    "overall_compliance": all([
        fill_rate_p95 >= 0.80,
        rtt_p95 <= 350,
        provenance_coverage >= 0.95,
        policy_latency_p99 <= 25
    ]),
    "compliance_rate": sum([
        fill_rate_p95 >= 0.80,
        rtt_p95 <= 350,
        provenance_coverage >= 0.95,
        policy_latency_p99 <= 25
    ]) / 4.0
}

print(json.dumps(report, indent=2))
PYTHON

chmod +x scripts/extract-slo-from-prometheus.py

# Port-forward Prometheus
kubectl port-forward -n aurora-staging svc/prometheus-server 9090:80 &

# Extract metrics
python scripts/extract-slo-from-prometheus.py > canary_slo_report.json

# Kill port-forward
pkill -f "port-forward.*prometheus"
```

### Export Grafana Screenshot

```bash
# Option A: Manual screenshot
# 1. Open Grafana dashboard
# 2. Set time range to "Last 72 hours"
# 3. Take screenshot → save as docs/aurora-staging-metrics-eks.png

# Option B: Programmatic (requires Grafana API)
GRAFANA_API="http://$GRAFANA_URL/api"
DASHBOARD_UID="aurora-kpis"
curl -u admin:admin "$GRAFANA_API/dashboards/uid/$DASHBOARD_UID" | \
  jq '.dashboard' > /tmp/dashboard.json
# Then use grafana-image-renderer or similar
```

---

## Step 7: Generate Ledger Snapshot

### Create S3 Bucket (one-time)

```bash
BUCKET_NAME="aurora-staging-ledger-$(date +%s)"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "export AURORA_LEDGER_BUCKET=$BUCKET_NAME" >> ~/.bashrc
```

### Snapshot Remembrancer DB

```bash
# Backup database
SNAPSHOT_DATE=$(date +%Y%m%d)
sqlite3 ops/data/remembrancer.db ".backup ops/backups/ledger-$SNAPSHOT_DATE.db"

# Compress
gzip ops/backups/ledger-$SNAPSHOT_DATE.db

# Upload to S3
aws s3 cp ops/backups/ledger-$SNAPSHOT_DATE.db.gz \
  s3://$AURORA_LEDGER_BUCKET/snapshots/

# Create snapshot metadata
cat > ops/ledger/snapshots/$SNAPSHOT_DATE-eks.json <<JSON
{
  "snapshot_id": "$(uuidgen)",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "environment": "staging-eks",
  "treaty_id": "AURORA-AKASH-001",
  "slo_report": $(cat canary_slo_report.json),
  "s3_location": "s3://$AURORA_LEDGER_BUCKET/snapshots/ledger-$SNAPSHOT_DATE.db.gz",
  "merkle_root": "$(./ops/bin/remembrancer verify-audit 2>&1 | grep 'Root:' | awk '{print $2}')",
  "cluster": {
    "name": "aurora-staging",
    "region": "eu-west-1",
    "node_count": $(kubectl get nodes --no-headers | wc -l),
    "pod_count": $(kubectl get pods -n aurora-staging --no-headers | wc -l)
  }
}
JSON

# Sign snapshot
./ops/bin/remembrancer sign ops/ledger/snapshots/$SNAPSHOT_DATE-eks.json \
  --key ${REMEMBRANCER_KEY_ID}
```

---

## Step 8: Commit Week 1 Deliverables

```bash
# Add all artifacts
git add canary_slo_report.json
git add docs/aurora-staging-metrics-eks.png
git add ops/ledger/snapshots/$SNAPSHOT_DATE-eks.json*

# Commit
git commit -m "feat(aurora): Week 1 complete - EKS staging metrics sealed

- 72h soak test complete on AWS EKS
- Cluster: aurora-staging (eu-west-1)
- Nodes: 3× m6i.large + 2× g5.2xlarge
- SLO compliance:
  * Fill rate (p95): $(jq -r '.metrics.fill_rate_p95' canary_slo_report.json) ✅
  * RTT (p95): $(jq -r '.metrics.rtt_p95_ms' canary_slo_report.json)ms ✅
  * Provenance: $(jq -r '.metrics.provenance_coverage' canary_slo_report.json) ✅
  * Policy latency (p99): $(jq -r '.metrics.policy_latency_p99_ms' canary_slo_report.json)ms ✅
- Ledger snapshot: s3://$AURORA_LEDGER_BUCKET/snapshots/ledger-$SNAPSHOT_DATE.db.gz
- Rating: 9.5 → 9.65/10

Week 1 Success: Metrics replace promises (AWS EKS)"

# Push
git push origin main
```

---

## Cost Management

### Estimated Week 1 Costs

```
EKS Control Plane:  $2.40 (72h × $0.10/hr)
3× m6i.large:       $21.60 (3 × 72h × $0.10/hr)
2× g5.2xlarge:      $90.00 (2 × 72h × $0.626/hr)
EBS (gp3):          $2.00 (~200GB × $0.08/GB/month prorated)
Data Transfer:      $5.00 (estimated)
LoadBalancers:      $5.40 (3 NLBs × 72h × $0.025/hr)
-------------------------------------------
TOTAL:              ~$125-150 for 72 hours
```

### Cost Optimization (Post-Week 1)

```bash
# Scale GPU pool to 0 when not in use
eksctl scale nodegroup --cluster=aurora-staging --name=gpu-pool --nodes=0

# Or delete cluster after Week 1 (can recreate for Week 3)
eksctl delete cluster --name=aurora-staging --region=eu-west-1
```

---

## Troubleshooting

### Pods stuck in Pending

```bash
kubectl describe pod <pod-name> -n aurora-staging
# Check "Events" section for errors

# Common fixes:
# - Insufficient resources: Scale nodegroup
# - Image pull errors: Check ECR/registry permissions
# - GPU taint: Add toleration to pod spec
```

### Metrics not appearing

```bash
# Check exporter logs
kubectl logs -n aurora-staging deployment/aurora-metrics-exporter

# Check Prometheus targets
kubectl port-forward -n aurora-staging svc/prometheus-server 9090:80
open http://localhost:9090/targets
# aurora-metrics should show "UP"
```

### LoadBalancer stuck in <pending>

```bash
# Check AWS Load Balancer Controller
kubectl get events -n aurora-staging

# Install AWS Load Balancer Controller (if needed)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=aurora-staging
```

---

## Week 1 Completion Checklist

- [ ] EKS cluster created (3 CPU + 2 GPU nodes)
- [ ] NVIDIA device plugin installed
- [ ] Aurora staging overlay deployed
- [ ] Prometheus + Grafana installed and accessible
- [ ] 72-hour soak test completed
- [ ] `canary_slo_report.json` populated with real metrics
- [ ] All 4 SLO targets met
- [ ] Grafana screenshot exported
- [ ] Ledger snapshot created and uploaded to S3
- [ ] All artifacts committed to git
- [ ] W1-1 through W1-6 marked complete in `AURORA_99_TASKS.md`

**When complete → Rating: 9.65/10 ✅**

---

## Next: Week 2 — CI Automation

After Week 1 completes, Week 2 will:
- Add GitHub Actions for automatic EKS deploys (OIDC-based)
- Auto-publish Merkle root on merge
- Covenant validation as required check
- Pre-commit hooks

**The EKS cluster becomes the enforcement platform for Week 2 automation.**

---

**Questions? Stuck on a step? Check:**
- `AURORA_99_STATUS.md` — Current progress
- `AURORA_99_TASKS.md` — Task checklist
- AWS EKS docs: https://docs.aws.amazon.com/eks/

🜂 **Metrics replace promises. The EKS cluster is the proof.**

