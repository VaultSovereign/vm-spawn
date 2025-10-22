# ⚡ AWS EKS Quickstart — 5 Commands to Week 1

**For operators who want to start the 72h soak test TODAY.**

---

## One-Liner Prerequisites

```bash
# macOS
brew install awscli eksctl kubectl helm jq

# Linux
curl -sL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz | sudo tar xz -C /usr/local/bin
```

---

## 5 Commands to Production Metrics

```bash
# 1. Create EKS cluster (15-20 min)
eksctl create cluster -f eks-aurora-staging.yaml

# 2. Install GPU support
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml

# 3. Deploy Aurora
kubectl apply -k ops/k8s/overlays/staging-eks

# 4. Install observability
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  -n aurora-staging -f ops/aws/prometheus-values.yaml --wait

helm upgrade --install grafana grafana/grafana \
  -n aurora-staging -f ops/aws/grafana-values.yaml --wait

# 5. Start 72h soak
date -u +"%Y-%m-%dT%H:%M:%SZ" | tee /tmp/aurora-soak-start.txt
echo "✅ Soak test started. Check back in 72 hours."
```

---

## After 72 Hours

```bash
# Get Grafana URL
kubectl get svc -n aurora-staging grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Take screenshot → save as docs/aurora-staging-metrics-eks.png

# Extract metrics from Prometheus (script coming in W1-4)
kubectl port-forward -n aurora-staging svc/prometheus-server 9090:80 &
python scripts/extract-slo-from-prometheus.py > canary_slo_report.json

# Create ledger snapshot
SNAPSHOT_DATE=$(date +%Y%m%d)
sqlite3 ops/data/remembrancer.db ".backup ops/backups/ledger-$SNAPSHOT_DATE.db"
gzip ops/backups/ledger-$SNAPSHOT_DATE.db

# Upload to S3
aws s3 cp ops/backups/ledger-$SNAPSHOT_DATE.db.gz s3://$AURORA_LEDGER_BUCKET/snapshots/

# Commit
git add canary_slo_report.json docs/aurora-staging-metrics-eks.png
git commit -m "feat(aurora): Week 1 complete - EKS metrics sealed"
```

---

## Cost

- **72 hours:** ~$125-150
- **Per month (if kept running):** ~$2,500-3,000

Scale down GPU nodes to $0 when not in use:
```bash
eksctl scale nodegroup --cluster=aurora-staging --name=gpu-pool --nodes=0
```

---

## Troubleshooting

**Cluster creation fails:**
```bash
# Check AWS quotas
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A  # Running On-Demand G instances

# If quota too low, request increase in AWS Console
```

**Pods stuck pending:**
```bash
kubectl describe pod <pod-name> -n aurora-staging
# Check "Events" for errors
```

**No metrics in Grafana:**
```bash
# Check Prometheus targets
kubectl port-forward -n aurora-staging svc/prometheus-server 9090:80
open http://localhost:9090/targets
# aurora-metrics should show "UP"
```

---

## Full Documentation

- **Complete guide:** [WEEK1_EKS_GUIDE.md](WEEK1_EKS_GUIDE.md)
- **EKS cluster config:** [eks-aurora-staging.yaml](eks-aurora-staging.yaml)
- **GitHub Actions CI/CD:** [.github/workflows/deploy-staging-eks.yml](.github/workflows/deploy-staging-eks.yml)

---

**🜂 Start now. 72 hours later, you have 9.65/10.**
