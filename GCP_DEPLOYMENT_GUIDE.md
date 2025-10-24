# VaultMesh GCP Deployment Guide

**Date:** 2025-10-23
**Status:** Ready to Deploy
**Target:** Google Kubernetes Engine (GKE)

---

## Overview

This guide deploys the complete VaultMesh stack to Google Cloud Platform:

- **ψ-Field** (Psi Field prediction service)
- **Scheduler** (10/10 production-hardened anchor scheduler)
- **Harbinger** (Layer 3 orchestration)
- **Federation** (Peer-to-peer federation)
- **Anchors** (Covenant anchoring service)
- **Sealer** (Cryptographic sealing service)
- **Monitoring** (Prometheus + Grafana)

---

## Prerequisites

### 1. GCP Account Setup
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### 2. Local Tools
```bash
# Verify installations
gcloud --version
kubectl version --client
docker --version
```

### 3. Environment Variables
```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export CLUSTER_NAME="vaultmesh-cluster"
export GCR_REGISTRY="gcr.io/${PROJECT_ID}"
```

---

## Phase 1: Container Registry Setup

### Create Artifact Registry
```bash
gcloud artifacts repositories create vaultmesh \
  --repository-format=docker \
  --location=${REGION} \
  --description="VaultMesh Docker images"

# Configure Docker authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

---

## Phase 2: Build and Push Docker Images

### Build Images
```bash
# Psi-Field
cd services/psi-field
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/psi-field:latest .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/psi-field:latest

# Scheduler
cd ../scheduler
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/scheduler:latest .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/scheduler:latest

# Return to root
cd ../..
```

**Expected Result:**
- ✅ psi-field:latest pushed
- ✅ scheduler:latest pushed

---

## Phase 3: Create GKE Cluster

### Standard GKE Cluster (Cost-Effective)
```bash
gcloud container clusters create ${CLUSTER_NAME} \
  --region=${REGION} \
  --release-channel=regular \
  --enable-stackdriver-kubernetes \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --network=default \
  --num-nodes=2 \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=6 \
  --machine-type=n2-standard-4 \
  --disk-type=pd-standard \
  --disk-size=50 \
  --enable-autorepair \
  --enable-autoupgrade \
  --maintenance-window-start=2025-01-01T00:00:00Z \
  --maintenance-window-duration=4h \
  --scopes=https://www.googleapis.com/auth/cloud-platform
```

**Cluster Specs:**
- **Nodes:** 2-6 (autoscaling)
- **Machine Type:** n2-standard-4 (4 vCPU, 16 GB RAM)
- **Region:** us-central1 (multi-zone HA)
- **Cost:** ~$150-450/month depending on load

### Get Credentials
```bash
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --region=${REGION} \
  --project=${PROJECT_ID}

# Verify
kubectl cluster-info
kubectl get nodes
```

---

## Phase 4: Create Namespace and Secrets

### Create VaultMesh Namespace
```bash
kubectl create namespace vaultmesh-prod

# Set default namespace
kubectl config set-context --current --namespace=vaultmesh-prod
```

### Create Secrets (if needed)
```bash
# Example: Docker registry secrets
kubectl create secret docker-registry gcr-secret \
  --docker-server=${REGION}-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat ~/.config/gcloud/application_default_credentials.json)" \
  --namespace=vaultmesh-prod
```

---

## Phase 5: Deploy Monitoring Stack

### Deploy Prometheus
```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus using Helm (recommended)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### Wait for External IPs
```bash
kubectl get svc -n monitoring -w
```

### Get Grafana Credentials
```bash
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
echo
```

---

## Phase 6: Deploy VaultMesh Services

### Deploy Psi-Field
```bash
# Update image in deployment
sed -i "s|IMAGE_PLACEHOLDER|${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/psi-field:latest|g" \
  services/psi-field/k8s/deployment.yaml

kubectl apply -f services/psi-field/k8s/deployment.yaml -n vaultmesh-prod
kubectl apply -f services/psi-field/k8s/service.yaml -n vaultmesh-prod
```

### Deploy Scheduler
```bash
# Update image in deployment
sed -i "s|IMAGE_PLACEHOLDER|${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/scheduler:latest|g" \
  services/scheduler/k8s/deployment.yaml

kubectl apply -f services/scheduler/k8s/deployment.yaml -n vaultmesh-prod
kubectl apply -f services/scheduler/k8s/service.yaml -n vaultmesh-prod
```

### Verify Deployments
```bash
kubectl get pods -n vaultmesh-prod
kubectl get svc -n vaultmesh-prod

# Check logs
kubectl logs -n vaultmesh-prod deployment/psi-field --tail=50
kubectl logs -n vaultmesh-prod deployment/scheduler --tail=50
```

---

## Phase 7: Configure Prometheus Scraping

### Apply VaultMesh Recording Rules
```bash
kubectl create configmap prometheus-vaultmesh-rules \
  --from-file=ops/prometheus/recording-rules.yaml \
  -n monitoring

# Reload Prometheus
kubectl rollout restart statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring
```

### Apply Alerting Rules
```bash
kubectl create configmap prometheus-vaultmesh-alerts \
  --from-file=ops/prometheus/combined-alerts.yaml \
  -n monitoring

# Reload Prometheus
kubectl rollout restart statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring
```

---

## Phase 8: Expose Services (Optional)

### Create Ingress (Recommended for production)
```bash
# Install nginx-ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Or use LoadBalancer (Simple)
```bash
# Update service type
kubectl patch svc psi-field -n vaultmesh-prod -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc scheduler -n vaultmesh-prod -p '{"spec":{"type":"LoadBalancer"}}'

# Get external IPs
kubectl get svc -n vaultmesh-prod
```

---

## Phase 9: Verification

### Health Checks
```bash
# Psi-Field
export PSI_FIELD_IP=$(kubectl get svc psi-field -n vaultmesh-prod -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${PSI_FIELD_IP}:8000/health

# Scheduler
export SCHEDULER_IP=$(kubectl get svc scheduler -n vaultmesh-prod -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${SCHEDULER_IP}:9091/health
```

### Metrics Verification
```bash
# Check Prometheus targets
export PROMETHEUS_IP=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open http://${PROMETHEUS_IP}:9090/targets

# Check Grafana dashboards
export GRAFANA_IP=$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open http://${GRAFANA_IP}
```

### Run Smoke Tests
```bash
# Port-forward if needed
kubectl port-forward -n vaultmesh-prod svc/psi-field 8000:8000 &
kubectl port-forward -n vaultmesh-prod svc/scheduler 9091:9091 &

# Test endpoints
curl http://localhost:8000/metrics | grep psi_field
curl http://localhost:9091/metrics | grep vmsh_anchors
```

---

## Phase 10: Cost Optimization

### Enable Cluster Autoscaler
```bash
gcloud container clusters update ${CLUSTER_NAME} \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=5 \
  --region=${REGION}
```

### Enable Node Auto-Provisioning (Optional)
```bash
gcloud container clusters update ${CLUSTER_NAME} \
  --enable-autoprovisioning \
  --min-cpu=2 \
  --max-cpu=16 \
  --min-memory=4 \
  --max-memory=64 \
  --region=${REGION}
```

### Set Resource Requests/Limits
Ensure all deployments have proper resource specifications to optimize bin-packing.

---

## Cost Estimates

### Monthly Costs (us-central1)

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| **GKE Control Plane** | Regional cluster | $73 |
| **Compute Nodes** | 2x n2-standard-4 (base) | ~$200 |
| **Persistent Disks** | 50 GB standard (Prometheus) | ~$2 |
| **Load Balancers** | 2-3 LBs (monitoring + services) | ~$54 |
| **Egress Traffic** | Varies by usage | ~$20-100 |
| **Total (Baseline)** | | **~$350-450/month** |

**Scale Up:**
- With autoscaling to 6 nodes: ~$600-800/month
- With GPU nodes (1x A100): +$2,500/month

---

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n vaultmesh-prod
kubectl logs <pod-name> -n vaultmesh-prod --previous
```

### Image Pull Errors
```bash
# Verify registry access
gcloud artifacts repositories describe vaultmesh --location=${REGION}
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

### Networking Issues
```bash
# Check firewall rules
gcloud compute firewall-rules list

# Check service endpoints
kubectl get endpoints -n vaultmesh-prod
```

---

## Cleanup (When Done)

```bash
# Delete cluster
gcloud container clusters delete ${CLUSTER_NAME} \
  --region=${REGION} \
  --quiet

# Delete images
gcloud artifacts repositories delete vaultmesh \
  --location=${REGION} \
  --quiet

# Verify cleanup
gcloud container clusters list
gcloud artifacts repositories list --location=${REGION}
```

---

## Next Steps

1. **Configure DNS** - Point domains to LoadBalancer IPs
2. **Enable TLS** - Use cert-manager for automatic certificates
3. **Set up CI/CD** - Deploy via Cloud Build or GitHub Actions
4. **Configure Backups** - Velero for cluster backups
5. **Enable Logging** - Cloud Logging for centralized logs
6. **Add AlertManager** - Configure Slack/PagerDuty notifications

---

## Quick Reference

```bash
# Get cluster info
gcloud container clusters describe ${CLUSTER_NAME} --region=${REGION}

# Scale deployment
kubectl scale deployment psi-field --replicas=3 -n vaultmesh-prod

# Update image
kubectl set image deployment/psi-field psi-field=${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/psi-field:v2.0 -n vaultmesh-prod

# View logs
kubectl logs -f deployment/scheduler -n vaultmesh-prod

# Execute command in pod
kubectl exec -it deployment/psi-field -n vaultmesh-prod -- bash
```

---

**Status:** ✅ Ready to Deploy
**Last Updated:** 2025-10-23
**Maintained By:** VaultMesh Engineering
