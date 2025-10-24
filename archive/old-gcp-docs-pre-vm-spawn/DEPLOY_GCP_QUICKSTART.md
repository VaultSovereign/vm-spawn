# VaultMesh GCP Deployment — Quick Start

**Status:** ✅ Ready to Deploy
**Time Required:** 15-20 minutes
**Cost:** ~$350-450/month

---

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed ([Install Guide](https://cloud.google.com/sdk/docs/install))
3. **Docker** installed and running
4. **kubectl** installed
5. **Helm** installed (for monitoring stack)

---

## One-Command Deployment

```bash
# 1. Set your GCP project ID
export PROJECT_ID="your-project-id-here"

# 2. Run the deployment script
./deploy-gcp.sh
```

That's it! The script will:
- ✅ Enable required GCP APIs
- ✅ Create Artifact Registry
- ✅ Build and push Docker images
- ✅ Create GKE cluster (2-6 nodes, n2-standard-4)
- ✅ Deploy Prometheus + Grafana
- ✅ Deploy Psi-Field and Scheduler services
- ✅ Expose services via LoadBalancers
- ✅ Display service endpoints and credentials

**Estimated time:** 15-20 minutes (most time is GKE cluster creation)

---

## What Gets Deployed

### Services
- **Psi-Field** — Prediction service with dual backends
- **Scheduler** — 10/10 production-hardened anchor scheduler
- **Prometheus** — Metrics collection and alerting
- **Grafana** — Visualization dashboards

### Infrastructure
- **GKE Cluster** — Regional cluster in us-central1
- **Node Pool** — 2-6 nodes (autoscaling), n2-standard-4
- **LoadBalancers** — 4 external IPs (services + monitoring)
- **Persistent Storage** — 50GB for Prometheus

---

## After Deployment

### Access Services

The script will output service URLs:

```
📊 Service Endpoints:
  Psi-Field:   http://<IP>:8000
  Scheduler:   http://<IP>:9091
  Prometheus:  http://<IP>:9090
  Grafana:     http://<IP>

🔐 Grafana Credentials:
  Username: admin
  Password: <shown in output>
```

### Verify Health

```bash
# Test Psi-Field
curl http://<PSI_FIELD_IP>:8000/health

# Test Scheduler
curl http://<SCHEDULER_IP>:9091/health

# Check metrics
curl http://<PSI_FIELD_IP>:8000/metrics | grep psi_field
curl http://<SCHEDULER_IP>:9091/metrics | grep vmsh
```

### View Pods

```bash
kubectl get pods -n vaultmesh-prod
kubectl logs -f deployment/psi-field -n vaultmesh-prod
```

---

## Customization

### Change Region
```bash
export REGION="europe-west1"
./deploy-gcp.sh
```

### Change Cluster Size
Edit `deploy-gcp.sh` and adjust:
- `--num-nodes=2` (initial size)
- `--min-nodes=2` and `--max-nodes=6` (autoscaling range)
- `--machine-type=n2-standard-4` (node size)

### Deploy Additional Services
```bash
# Deploy Harbinger
kubectl apply -f services/harbinger/k8s/ -n vaultmesh-prod

# Deploy Federation
kubectl apply -f services/federation/k8s/ -n vaultmesh-prod
```

---

## Monitoring

### Access Grafana
1. Open Grafana URL from deployment output
2. Login with admin credentials
3. Import VaultMesh dashboards:
   - Go to Dashboards → Import
   - Upload from `ops/grafana/dashboards/`

### Access Prometheus
1. Open Prometheus URL
2. Go to Status → Targets
3. Verify VaultMesh services are being scraped

---

## Cost Management

### View Current Costs
```bash
gcloud billing accounts list
gcloud beta billing projects describe $PROJECT_ID
```

### Reduce Costs
```bash
# Scale down to 1 node (dev/test)
gcloud container clusters update vaultmesh-cluster \
  --region=us-central1 \
  --min-nodes=1 \
  --max-nodes=3

# Or pause cluster (stop all nodes)
gcloud container clusters resize vaultmesh-cluster \
  --region=us-central1 \
  --num-nodes=0
```

### Delete Everything
```bash
# Delete cluster (removes all resources)
gcloud container clusters delete vaultmesh-cluster \
  --region=us-central1 \
  --quiet

# Delete container images
gcloud artifacts repositories delete vaultmesh \
  --location=us-central1 \
  --quiet
```

---

## Troubleshooting

### Image Pull Errors
```bash
# Re-authenticate Docker
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n vaultmesh-prod
kubectl logs <pod-name> -n vaultmesh-prod
```

### Can't Access Services
```bash
# Check if LoadBalancers have IPs
kubectl get svc -n vaultmesh-prod
kubectl get svc -n monitoring

# May take 2-3 minutes for IPs to be assigned
```

### Out of Quota
```bash
# Check quotas
gcloud compute project-info describe --project=$PROJECT_ID

# Request quota increase via GCP Console
```

---

## Next Steps

1. **Configure DNS** — Point your domain to LoadBalancer IPs
2. **Enable HTTPS** — Install cert-manager for TLS certificates
3. **Set up CI/CD** — Deploy via Cloud Build or GitHub Actions
4. **Configure Backups** — Use Velero for cluster backups
5. **Enable Alerts** — Configure AlertManager for Slack/PagerDuty

---

## Support

- **Deployment Guide:** [GCP_DEPLOYMENT_GUIDE.md](GCP_DEPLOYMENT_GUIDE.md) (comprehensive)
- **GKE Docs:** [docs/gke/](docs/gke/)
- **Monitoring Setup:** [ops/prometheus/README.md](ops/prometheus/README.md)

---

## Estimated Costs

| Component | Monthly Cost |
|-----------|--------------|
| GKE Control Plane | $73 |
| Compute Nodes (2-6) | $200-600 |
| LoadBalancers (4) | $72 |
| Storage (50GB) | $2 |
| Network Egress | $20-100 |
| **Total** | **~$350-850** |

**Tip:** Use preemptible nodes to save ~60% on compute costs (good for dev/test).

---

**Ready to deploy?**

```bash
export PROJECT_ID="your-project-id"
./deploy-gcp.sh
```

🚀 **Let's go!**
