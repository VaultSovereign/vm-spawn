# GCP & Kubernetes Connectivity Guide

**Status:** Production
**Last Updated:** 2025-10-24
**Cluster:** vaultmesh-minimal (us-central1)

---

## Quick Start

```bash
# Authenticate
gcloud auth login
gcloud config set project vm-spawn

# Configure kubectl
gcloud container clusters get-credentials vaultmesh-minimal --region=us-central1

# Verify
kubectl get nodes
kubectl get pods -n vaultmesh
```

---

## Prerequisites

### 1. Install GCP CLI Tools

```bash
# Install gcloud
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install kubectl auth plugin (REQUIRED for GKE)
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

# Verify
gcloud version
kubectl version --client
gke-gcloud-auth-plugin --version
```

### 2. Enable Auth Plugin

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
```

---

## Authentication

### Service Account (Recommended for CI/CD)

```bash
# Authenticate with service account
gcloud auth activate-service-account --key-file=/path/to/key.json

# Set project
gcloud config set project vm-spawn
```

### User Account (Interactive)

```bash
# Login interactively
gcloud auth login

# Application default credentials (for local development)
gcloud auth application-default login
```

### Check Active Auth

```bash
gcloud auth list
# Should show guardian@vaultmesh.org or your service account
```

---

## Kubernetes Configuration

### Get Cluster Credentials

```bash
# Fetch kubeconfig for vaultmesh-minimal
gcloud container clusters get-credentials vaultmesh-minimal \
  --region=us-central1 \
  --project=vm-spawn

# Verify context
kubectl config current-context
# Should output: gke_vm-spawn_us-central1_vaultmesh-minimal
```

### List Available Clusters

```bash
gcloud container clusters list --format="table(name,location,status)"
```

### Switch Contexts

```bash
# List all contexts
kubectl config get-contexts

# Switch to vaultmesh
kubectl config use-context gke_vm-spawn_us-central1_vaultmesh-minimal
```

---

## Verification

### Test Cluster Access

```bash
# Check nodes
kubectl get nodes

# Expected output:
# NAME                                         STATUS   ROLES    AGE
# gk3-vaultmesh-minimal-pool-2-xxxxx          Ready    <none>   Xh
# gk3-vaultmesh-minimal-pool-2-xxxxx          Ready    <none>   Xh
# gk3-vaultmesh-minimal-pool-2-xxxxx          Ready    <none>   Xh
```

### Check Deployments

```bash
# List namespaces
kubectl get ns

# Check vaultmesh namespace
kubectl get pods -n vaultmesh

# Expected services:
# - psi-field (1/1 Running)
# - scheduler (1/1 Running)
# - vaultmesh-analytics (2/2 Running)
```

### Verify Service Health

```bash
# Check scheduler
kubectl exec -n vaultmesh deployment/scheduler -- \
  curl -sf http://localhost:9091/health

# Check psi-field
kubectl exec -n vaultmesh deployment/psi-field -- \
  curl -sf http://localhost:8000/health
```

---

## Common Issues & Solutions

### Issue: kubectl commands hang

**Symptoms:**
- `kubectl get nodes` hangs without output
- Commands time out after 30+ seconds

**Solutions:**

1. **Check auth plugin:**
   ```bash
   export USE_GKE_GCLOUD_AUTH_PLUGIN=True
   gke-gcloud-auth-plugin --version
   ```

2. **Refresh credentials:**
   ```bash
   gcloud auth login
   gcloud container clusters get-credentials vaultmesh-minimal --region=us-central1
   ```

3. **Use explicit timeout:**
   ```bash
   timeout 10 kubectl get nodes --request-timeout=5s
   ```

4. **Check cluster status:**
   ```bash
   gcloud container clusters describe vaultmesh-minimal \
     --region=us-central1 \
     --format="value(status,endpoint)"
   # Should output: RUNNING <IP>
   ```

5. **Network connectivity:**
   ```bash
   # Test GKE API server
   ENDPOINT=$(gcloud container clusters describe vaultmesh-minimal \
     --region=us-central1 --format="value(endpoint)")
   curl -k https://$ENDPOINT/healthz
   ```

---

### Issue: "gke-gcloud-auth-plugin not found"

**Error:**
```
CRITICAL: gke-gcloud-auth-plugin, which is needed for continued use of kubectl, was not found
```

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

# macOS
gcloud components install gke-gcloud-auth-plugin

# Verify
which gke-gcloud-auth-plugin
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
```

---

### Issue: "No resources found in vaultmesh namespace"

**Possible Causes:**
1. Wrong namespace
2. Resources not deployed
3. RBAC permissions issue

**Solutions:**
```bash
# List all namespaces
kubectl get ns

# Check if namespace exists
kubectl get ns vaultmesh

# If missing, create it:
kubectl create namespace vaultmesh

# Check your permissions
kubectl auth can-i get pods --namespace=vaultmesh
```

---

### Issue: "error: You must be logged in to the server (Unauthorized)"

**Solutions:**
```bash
# Re-authenticate
gcloud auth login

# Refresh cluster credentials
gcloud container clusters get-credentials vaultmesh-minimal --region=us-central1

# If using service account:
gcloud auth activate-service-account --key-file=/path/to/key.json
```

---

## Accessing Services

### Port Forwarding (Local Access)

```bash
# Forward Analytics dashboard
kubectl port-forward -n vaultmesh svc/vaultmesh-analytics 3000:3000
# Visit: http://localhost:3000

# Forward scheduler metrics
kubectl port-forward -n vaultmesh svc/scheduler 9091:9091
# Visit: http://localhost:9091/metrics

# Forward psi-field API
kubectl port-forward -n vaultmesh svc/psi-field 8000:8000
# Visit: http://localhost:8000/health
```

### In-Cluster DNS

Services are accessible within the cluster using these DNS names:

```
psi-field:8000
scheduler:9091
vaultmesh-analytics:3000
aurora-router:8080
```

Example from within a pod:
```bash
curl http://psi-field:8000/health
curl http://scheduler:9091/metrics
```

### External Access (via Ingress)

External access requires ingress configuration (not yet set up):

```bash
# Check ingress
kubectl get ingress -n vaultmesh

# Check LoadBalancer services
kubectl get svc -n vaultmesh --field-selector spec.type=LoadBalancer

# Check SSL certificates
kubectl get managedcertificate -n vaultmesh
```

---

## Cluster Information

### Current Configuration

| Property | Value |
|----------|-------|
| **Project** | vm-spawn |
| **Cluster** | vaultmesh-minimal |
| **Region** | us-central1 |
| **Type** | GKE Autopilot |
| **Nodes** | 3 (auto-scaled) |
| **Version** | v1.33.5-gke.1080000 |
| **Endpoint** | 136.112.55.240 |

### Deployed Services (vaultmesh namespace)

| Service | Replicas | Port | Type |
|---------|----------|------|------|
| psi-field | 1 | 8000 | ClusterIP |
| scheduler | 1 | 9091 | ClusterIP |
| vaultmesh-analytics | 2 | 3000 | ClusterIP |

### KEDA Autoscaling

```bash
# Check KEDA operator
kubectl get pods -n keda

# Check ScaledObjects
kubectl get scaledobject -n vaultmesh

# Check HorizontalPodAutoscalers
kubectl get hpa -n vaultmesh
```

---

## Useful Commands

### Logs

```bash
# View pod logs
kubectl logs -n vaultmesh deployment/scheduler --tail=50

# Follow logs
kubectl logs -n vaultmesh -f deployment/vaultmesh-analytics

# Previous container logs (if crashed)
kubectl logs -n vaultmesh pod/scheduler-xxx --previous
```

### Debugging

```bash
# Describe pod
kubectl describe pod -n vaultmesh scheduler-xxx

# Get pod YAML
kubectl get pod -n vaultmesh scheduler-xxx -o yaml

# Execute command in pod
kubectl exec -n vaultmesh deployment/scheduler -- env

# Interactive shell (if available)
kubectl exec -it -n vaultmesh deployment/scheduler -- sh
```

### Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n vaultmesh

# Describe nodes
kubectl describe nodes
```

### Events

```bash
# Cluster events
kubectl get events -n vaultmesh --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n vaultmesh --watch
```

---

## Scripts & Automation

### Production Smoke Test

```bash
# Run comprehensive infrastructure test
./SMOKE_TEST_PRODUCTION.sh

# Skip authentication test
./SMOKE_TEST_PRODUCTION.sh --skip-auth

# Skip external ingress tests
./SMOKE_TEST_PRODUCTION.sh --skip-ingress
```

### Quick Health Check

```bash
#!/bin/bash
# quick-health.sh

echo "=== Cluster Status ==="
kubectl get nodes

echo -e "\n=== VaultMesh Pods ==="
kubectl get pods -n vaultmesh

echo -e "\n=== KEDA Status ==="
kubectl get scaledobject -n vaultmesh

echo -e "\n=== Service Endpoints ==="
kubectl get svc -n vaultmesh
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to GKE
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2

      - name: Install kubectl auth plugin
        run: |
          sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials vaultmesh-minimal \
            --region=us-central1 \
            --project=vm-spawn

      - name: Deploy
        run: |
          kubectl apply -f k8s/deployments.yaml -n vaultmesh
          kubectl rollout status deployment/scheduler -n vaultmesh
```

---

## Security Best Practices

### 1. Use Service Accounts for Automation

Never use personal credentials in CI/CD. Create dedicated service accounts:

```bash
# Create service account
gcloud iam service-accounts create vaultmesh-deployer \
  --display-name="VaultMesh Deployer"

# Grant permissions
gcloud projects add-iam-policy-binding vm-spawn \
  --member="serviceAccount:vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Create key
gcloud iam service-accounts keys create key.json \
  --iam-account=vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com
```

### 2. Least Privilege Access

Only grant necessary permissions:
- `roles/container.viewer` - Read-only access
- `roles/container.developer` - Deploy and manage workloads
- `roles/container.admin` - Full cluster admin (use sparingly)

### 3. Rotate Credentials Regularly

```bash
# List service account keys
gcloud iam service-accounts keys list \
  --iam-account=vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com

# Delete old keys
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com
```

---

## Troubleshooting Checklist

When kubectl isn't working, check in order:

- [ ] `gke-gcloud-auth-plugin` installed?
- [ ] `USE_GKE_GCLOUD_AUTH_PLUGIN=True` set?
- [ ] `gcloud auth list` shows active account?
- [ ] `gcloud config get-value project` = vm-spawn?
- [ ] Cluster status = RUNNING? (`gcloud container clusters describe...`)
- [ ] Kubeconfig current-context correct?
- [ ] Network connectivity to 136.112.55.240?
- [ ] RBAC permissions sufficient?

---

## Additional Resources

- [GKE Quickstart](https://cloud.google.com/kubernetes-engine/docs/quickstart)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [KEDA Documentation](https://keda.sh/docs/)
- [GKE Auth Plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)

---

## Support

For VaultMesh-specific issues:
- GitHub Issues: https://github.com/VaultSovereign/vm-spawn/issues
- Documentation: `docs/` directory
- Runbooks: `docs/operations/`

---

*Last updated: 2025-10-24 by Phase VII Track 1 Session 2*
