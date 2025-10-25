# VaultMesh CI/CD - Production Deployment Pipeline

**Repository**: vm-spawn (VaultSovereign/vm-spawn)
**Cluster**: vaultmesh-minimal (GKE Autopilot, us-central1)
**Security**: Keyless OIDC + Workload Identity Federation
**Status**: ✅ Ready for deployment (pending WIF setup)

---

## 🎯 Quick Start

### For First-Time Setup (15 minutes):

```bash
# 1. Complete Workload Identity Federation (via Console)
# Visit: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=vm-spawn
# See detailed instructions below

# 2. Run setup script
cd /home/sovereign/vm-spawn/.ci-cd
./setup-manual-steps.sh
# Script will prompt for GitHub repo: VaultSovereign/vm-spawn

# 3. Add GitHub Secrets (from script output)
# Repository → Settings → Secrets and variables → Actions
# Add: GCP_WIF_PROVIDER and GCP_DEPLOYER_SA

# 4. Push to main branch - automatic deployment!
```

### For Subsequent Deployments:

```bash
# Just push code changes - CI/CD handles the rest
git add services/SERVICE_NAME
git commit -m "Update SERVICE_NAME"
git push origin main

# Monitor: https://github.com/VaultSovereign/vm-spawn/actions
```

---

## 📁 Repository Structure

```
vm-spawn/
├── .github/workflows/
│   ├── ci-cd-autopilot.yml        ← New keyless CI/CD workflow
│   ├── deploy.yml                 ← Existing Helm deployment (manual)
│   ├── aurora-ci.yml              ← Existing Aurora CI
│   └── ...                        ← Other workflows
├── .ci-cd/                        ← CI/CD configuration files
│   ├── README.md                  ← This file
│   ├── rbac-deployer.yaml         ← ✅ Already applied to GKE cluster
│   ├── setup-manual-steps.sh      ← Setup automation script
│   └── cloudbuild.yaml            ← Cloud Build alternative
├── services/                      ← Microservices (all have Dockerfiles)
│   ├── psi-field/
│   │   ├── Dockerfile             ← ✅ Ready
│   │   ├── k8s/                   ← Kubernetes manifests
│   │   └── src/                   ← Python source
│   ├── scheduler/
│   │   ├── Dockerfile             ← ✅ Ready
│   │   ├── k8s/
│   │   └── src/                   ← Python source
│   ├── aurora-router/
│   │   ├── Dockerfile             ← ✅ Ready
│   │   ├── k8s/
│   │   └── src/                   ← TypeScript source
│   ├── aurora-intelligence/
│   │   ├── Dockerfile             ← ✅ Ready
│   │   ├── k8s/
│   │   └── app/                   ← Python source
│   └── vaultmesh-analytics/
│       ├── Dockerfile             ← ✅ Ready
│       ├── k8s/
│       └── app/                   ← Next.js source
└── engines/                       ← Python engines (future CI/CD)
    └── aurora-intelligence/
```

**All 5 core services have Dockerfiles and are ready for automated deployment.**

---

## 🔧 Workflow: `.github/workflows/ci-cd-autopilot.yml`

### What It Does:

1. **Detect Changes** (automatic)
   - Git diff finds modified services in `services/` directory
   - Only rebuilds changed services (efficient)

2. **Build & Push** (parallel)
   - Builds Docker images with `:SHA` and `:latest` tags
   - Pushes to `us-central1-docker.pkg.dev/vm-spawn/vaultmesh`
   - Authenticates via OIDC (no keys!)

3. **Deploy** (rolling update)
   - Updates deployment images in `vaultmesh` namespace
   - Waits for rollout completion (health checks)
   - Auto-rollback on failure

4. **Verify**
   - Checks pod status
   - Displays deployment summary

### Triggers:

- **Automatic**: Push to `main` branch (changes in `services/`)
- **Manual**: Actions tab → "VaultMesh Deploy" → Run workflow

### Manual Trigger Options:

```yaml
service: aurora-intelligence    # Deploy specific service
force_rebuild: true            # Rebuild all services
```

---

## 🛡️ Security Architecture

```
GitHub Actions Runner
    ↓ [OIDC Token: sub, repository, actor]
Workload Identity Pool: gh-oidc-pool
    ↓ [Validate issuer + repository claim]
Service Account: vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com
    ↓ [IAM Permissions]
GCP Resources:
  - Artifact Registry (push images)
  - GKE (get credentials)
  - Cloud Logging (write logs)
    ↓ [Kubernetes RBAC]
GKE Cluster: vaultmesh-minimal
  - Namespace: vaultmesh (deployer-edit role)
  - Permissions: Deploy, update, scale workloads
  - Restrictions: NO cluster-admin, NO cross-namespace
```

**Zero long-lived keys. Credentials expire in 1 hour. Full audit trail.**

---

## 🚀 Setup Instructions

### Prerequisites:

- ✅ GKE Autopilot cluster `vaultmesh-minimal` running
- ✅ Service account `vaultmesh-deployer` created
- ✅ Kubernetes RBAC applied (deployer-edit role)
- ✅ Workload Identity Pool `gh-oidc-pool` created
- ⚠️ OIDC Provider needs manual Console setup

### Step 1: Create OIDC Provider (5 minutes)

**Why Console**: gcloud CLI has validation issues with GitHub OIDC attributes.

1. Visit: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=vm-spawn

2. Click `gh-oidc-pool` → **Add Provider**

3. Configure:
   ```
   Provider type: OpenID Connect (OIDC)
   Provider name: github
   Issuer: https://token.actions.githubusercontent.com
   Audiences: Default

   Attribute mapping:
     google.subject = assertion.sub
     attribute.repository = assertion.repository
     attribute.actor = assertion.actor

   Attribute conditions (optional - restrict to this repo):
     attribute.repository == "VaultSovereign/vm-spawn"
   ```

4. Click **Save**

### Step 2: Run Setup Script

```bash
cd /home/sovereign/vm-spawn/.ci-cd
./setup-manual-steps.sh
```

**Script prompts**:
```
Enter your GitHub repository (format: owner/repo-name): VaultSovereign/vm-spawn
```

**Script actions**:
- Verifies OIDC provider exists
- Binds repository to service account
- Displays GitHub secrets configuration
- Verifies all components

**Expected output**:
```
✅ OIDC Provider 'github' exists
   Resource Name: projects/572946311311/locations/global/workloadIdentityPools/gh-oidc-pool/providers/github

Binding repository VaultSovereign/vm-spawn to vaultmesh-deployer...
✅ Service account binding complete

Add these secrets to your GitHub repository:

Secret 1: GCP_WIF_PROVIDER
  Value:
  projects/572946311311/locations/global/workloadIdentityPools/gh-oidc-pool/providers/github

Secret 2: GCP_DEPLOYER_SA
  Value:
  vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com
```

### Step 3: Add GitHub Secrets

1. Go to: https://github.com/VaultSovereign/vm-spawn/settings/secrets/actions

2. Click **New repository secret**

3. Add secret 1:
   - **Name**: `GCP_WIF_PROVIDER`
   - **Value**: `projects/572946311311/locations/global/workloadIdentityPools/gh-oidc-pool/providers/github`

4. Add secret 2:
   - **Name**: `GCP_DEPLOYER_SA`
   - **Value**: `vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com`

### Step 4: Test Deployment

#### Option A: Trigger via Code Change

```bash
# Make a small change to trigger CI/CD
cd /home/sovereign/vm-spawn
echo "# CI/CD Test" >> services/psi-field/README.md
git add services/psi-field/README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

#### Option B: Manual Trigger

1. Go to: https://github.com/VaultSovereign/vm-spawn/actions
2. Click "VaultMesh Deploy"
3. Click "Run workflow"
4. Select branch: `main`
5. Enter service name: `psi-field` (or leave empty for all)
6. Click "Run workflow"

**Monitor**: Actions tab → Click on running workflow

---

## 📊 What Was Already Deployed

Current state in GKE `vaultmesh` namespace:

| Service | Image Tag | Replicas | Status |
|---------|-----------|----------|--------|
| **psi-field** | latest | 1 | ✅ Running |
| **scheduler** | 1.1.0 | 1 | ✅ Running |
| **aurora-router** | 0.2.0 | 2 | ✅ Running |
| **aurora-intelligence** | 0.1.2 | 2 | ✅ Running |
| **vaultmesh-analytics** | 1.0.0 | 2 | ✅ Running |

**Next CI/CD deployment will**:
- Build new images tagged with git commit SHA
- Perform rolling updates (zero downtime)
- Update to latest code from main branch

---

## 🔍 Verification

### Check CI/CD is working:

```bash
# 1. Verify workflow file exists
ls -la /home/sovereign/vm-spawn/.github/workflows/ci-cd-autopilot.yml

# 2. Verify GitHub secrets are set
# https://github.com/VaultSovereign/vm-spawn/settings/secrets/actions
# Should see: GCP_WIF_PROVIDER, GCP_DEPLOYER_SA

# 3. Check Kubernetes RBAC
kubectl get role deployer-edit -n vaultmesh
kubectl get rolebinding deployer-edit-binding -n vaultmesh

# 4. Verify service account
gcloud iam service-accounts describe \
  vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com \
  --project=vm-spawn

# 5. Check IAM binding
gcloud iam service-accounts get-iam-policy \
  vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com \
  --project=vm-spawn | grep principalSet
```

---

## 🎛️ Usage Examples

### Deploy Single Service:

**Via Manual Trigger**:
1. Actions → VaultMesh Deploy → Run workflow
2. Service: `aurora-intelligence`
3. Run workflow

**Via Code Change**:
```bash
cd services/aurora-intelligence
# Make changes
git add .
git commit -m "feat: add new capability"
git push origin main
# Only aurora-intelligence will rebuild and deploy
```

### Deploy All Services:

**Via Manual Trigger**:
1. Actions → VaultMesh Deploy → Run workflow
2. Leave service empty
3. Check "Force rebuild"
4. Run workflow

### Rollback:

```bash
# Automatic rollback happens if deployment fails

# Manual rollback:
kubectl rollout undo deployment/SERVICE_NAME -n vaultmesh
kubectl rollout status deployment/SERVICE_NAME -n vaultmesh
```

### View Logs:

```bash
# GitHub Actions logs
# https://github.com/VaultSovereign/vm-spawn/actions

# Pod logs
kubectl logs -n vaultmesh deployment/SERVICE_NAME --tail=100 --follow

# Deployment events
kubectl describe deploy SERVICE_NAME -n vaultmesh
```

---

## 🆚 Comparison with Existing Workflows

| Workflow | Purpose | Authentication | When to Use |
|----------|---------|----------------|-------------|
| **ci-cd-autopilot.yml** (NEW) | Automated deployment to production | OIDC (keyless) | Push to main → auto-deploy |
| **deploy.yml** (Existing) | Manual Helm deployment | kubeconfig secret | Staging/testing Helm charts |
| **aurora-ci.yml** (Existing) | Aurora service testing | N/A (no cluster) | CI testing only |

**Recommendation**: Use **ci-cd-autopilot.yml** for all production deployments.

---

## 🔧 Troubleshooting

### "Error: google.auth.exceptions.RefreshError"

**Cause**: Workload Identity Federation not configured

**Fix**:
1. Verify OIDC provider exists:
   ```bash
   gcloud iam workload-identity-pools providers describe github \
     --project=vm-spawn --location=global \
     --workload-identity-pool=gh-oidc-pool
   ```

2. Re-run setup script:
   ```bash
   cd .ci-cd && ./setup-manual-steps.sh
   ```

### "Error from server (Forbidden)"

**Cause**: Kubernetes RBAC not applied

**Fix**:
```bash
kubectl apply -f .ci-cd/rbac-deployer.yaml
```

### "Failed to pull image"

**Cause**: Image doesn't exist or Workload Identity not configured for pods

**Fix**:
```bash
# Check if image exists
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/vm-spawn/vaultmesh \
  --include-tags | grep SERVICE_NAME

# If missing, trigger rebuild
# GitHub → Actions → Run workflow
```

### Workflow doesn't trigger

**Cause**: No changes in `services/` directory

**Fix**:
- Ensure your changes are in `services/SERVICE_NAME/`
- OR use manual trigger with "Force rebuild"

---

## 📈 Next Enhancements

### Phase 3: Monitoring
- Cloud Monitoring dashboards
- KEDA scaling alerts
- Deployment metrics
- Cost tracking

### Phase 4: Testing
- Integration tests in CI
- Load testing
- Security scanning (SAST/DAST)

### Phase 5: Progressive Delivery
- Canary deployments
- Traffic splitting
- Automated rollback triggers

---

## 📚 Related Documentation

- **Phase 2 Summary**: `/home/sovereign/vm-automation/ci-cd/PHASE2-SUMMARY.md`
- **Codex v1.0**: `/home/sovereign/vm-automation/codex-20251025T1104Z/`
- **GKE Autopilot Docs**: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
- **Workload Identity Federation**: https://cloud.google.com/iam/docs/workload-identity-federation

---

## ✅ Pre-Flight Checklist

Before first deployment:

- [ ] OIDC provider created via Console
- [ ] Setup script executed successfully
- [ ] GitHub secrets configured (GCP_WIF_PROVIDER, GCP_DEPLOYER_SA)
- [ ] Workflow file exists in `.github/workflows/ci-cd-autopilot.yml`
- [ ] All 5 services have Dockerfiles
- [ ] Kubernetes RBAC applied
- [ ] Service account has IAM roles

---

**Status**: ✅ Ready for first keyless automated deployment!

**The laptop is retired. The mesh now deploys itself.**

🜂 **Sovereign CI/CD Operational**
