# VaultMesh GCP Infrastructure Audit

**Project ID:** vaultmesh-473618
**Date:** 2025-10-23
**Status:** Pre-Deployment Investigation

---

## Executive Summary

Your GCP project **already has infrastructure running**. Before deploying anything new, here's what's currently active:

**Running Services:**
- ✅ 2 Cloud Run services (ai-companion-proxy, vaultmesh-portal)
- ✅ 1 Compute Engine VM (workstations instance)
- ✅ 6 Secret Manager secrets configured
- ✅ 4 Artifact Registry repositories with Docker images
- ✅ 3 Cloud Storage buckets (including receipts bucket)

**Not Yet Deployed:**
- ❌ No GKE clusters
- ❌ No Pub/Sub topics
- ❌ No VaultMesh services from this repo (psi-field, scheduler, etc.)

---

## Current Infrastructure

### 1. Cloud Run Services (Serverless)

| Service | Region | URL | Status |
|---------|--------|-----|--------|
| **ai-companion-proxy** | europe-west1 | https://ai-companion-proxy-679128723439.europe-west1.run.app | ✅ Running |
| **vaultmesh-portal** | europe-west3 | https://vaultmesh-portal-679128723439.europe-west3.run.app | ✅ Running |

**Deployed By:**
- ai-companion-proxy: Compute Engine default SA
- vaultmesh-portal: guardian@vaultmesh.org (you)

**Last Deployment:**
- ai-companion-proxy: 2025-10-03
- vaultmesh-portal: 2025-10-03

---

### 2. Compute Engine

| Instance | Zone | Type | Internal IP | External IP | Status |
|----------|------|------|-------------|-------------|--------|
| workstations-89d29b41-... | europe-west3-b | e2-standard-4 | 10.156.0.26 | 34.179.146.101 | ✅ Running |

**Purpose:** Cloud Workstation (development environment)

**Estimated Cost:** ~$100-150/month (e2-standard-4 running 24/7)

---

### 3. Secret Manager

| Secret Name | Environment | Purpose | Created |
|-------------|-------------|---------|---------|
| vaultmesh-dev-db-password | dev | Database password | 2025-10-01 |
| vaultmesh-dev-guardian-signing-key | dev | GPG signing key | 2025-10-01 |
| vaultmesh-dev-openrouter | dev | OpenRouter API key | 2025-10-01 |
| vaultmesh-prod-db-password | prod | Database password | 2025-10-01 |
| vaultmesh-prod-guardian-signing-key | prod | GPG signing key | 2025-10-01 |
| vaultmesh-prod-openrouter | prod | OpenRouter API key | 2025-10-01 |

**Status:** ✅ Fully configured for both dev and prod environments

---

### 4. Artifact Registry (Docker Images)

| Repository | Location | Images | Size | Purpose |
|------------|----------|--------|------|---------|
| **forge** | europe-west1 | ai-companion-proxy (3 versions) | 67 MB | AI proxy service |
| **vaultmesh** | europe-west1 | None | 0 MB | Empty (ready for use) |
| **vaultmesh-repo** | europe-west1 | None | 0 MB | Empty (ready for use) |
| **vaultmesh** | europe-west3 | portal (1 version) | 21 MB | Portal service |

**Latest Images:**
- `europe-west1-docker.pkg.dev/vaultmesh-473618/forge/ai-companion-proxy:latest`
- `europe-west3-docker.pkg.dev/vaultmesh-473618/vaultmesh/portal:latest`

---

### 5. Cloud Storage Buckets

| Bucket | Location | Purpose | Size | Created |
|--------|----------|---------|------|---------|
| **vaultmesh-473618-vaultmesh-receipts** | europe-west1 | Receipts storage | Unknown | 2025-10-05 |
| vaultmesh-473618_cloudbuild | US | Cloud Build artifacts | Unknown | 2025-10-02 |
| cloud-ai-platform-... | us-central1 | Vertex AI workspace | Unknown | 2025-10-07 |

**Important:** Your receipts bucket is already set up! 🎉

---

### 6. IAM Service Accounts

| Display Name | Email | Purpose |
|--------------|-------|---------|
| **VaultMesh Deployer** | vaultmesh-deployer@... | Deployment automation |
| **AI Companion Proxy** | ai-companion-proxy@... | AI proxy service |
| **Scheduler** | scheduler@... | Scheduler service |
| **VaultMesh Loop SA** | vaultmesh-loop-sa@... | Loop/monitoring |
| **Meta Publisher** | meta-publisher@... | Publishing |
| App Engine default | vaultmesh-473618@appspot | Default |
| Compute Engine default | 679128723439-compute@ | Default |

---

### 7. Enabled APIs

✅ **Already Enabled:**
- Kubernetes Engine API (container.googleapis.com)
- Compute Engine API
- Artifact Registry API
- Secret Manager API
- Cloud Pub/Sub API
- Cloud Storage API
- Container Registry API
- BigQuery Storage API

**No additional APIs need to be enabled!**

---

### 8. Networking

**VPC:** Default network
**Firewall Rules:**
- default-allow-ssh (port 22)
- default-allow-rdp (port 3389)
- default-allow-internal (all internal traffic)
- default-allow-icmp

**No GKE clusters found** (no K8s networking configured yet)

---

## What's NOT Running Yet

❌ **GKE Clusters:** None
❌ **Kubernetes Services:** None
❌ **Pub/Sub Topics:** None
❌ **VaultMesh Services from this repo:**
   - psi-field
   - scheduler
   - harbinger
   - federation
   - anchors
   - sealer

---

## Cost Estimate (Current State)

| Component | Monthly Cost |
|-----------|--------------|
| Cloud Run (ai-companion-proxy) | ~$0-20 (depends on traffic) |
| Cloud Run (vaultmesh-portal) | ~$0-20 (depends on traffic) |
| Compute Engine (e2-standard-4) | ~$120-150 |
| Secret Manager (6 secrets) | ~$0.06 |
| Artifact Registry (storage) | ~$0.10 |
| Cloud Storage | ~$0-5 |
| **Total (current)** | **~$120-195/month** |

**Main cost driver:** The e2-standard-4 workstation instance running 24/7.

---

## Deployment Recommendations

### Option 1: Deploy VaultMesh to GKE (New Cluster)

**What it adds:**
- New GKE cluster (separate from existing Cloud Run services)
- Deploy psi-field, scheduler, and other services
- KEDA for scale-to-zero (minimal cost profile)

**Impact:**
- Existing Cloud Run services: **Unchanged**
- Existing secrets: **Can be reused**
- Existing workstation: **Unchanged**
- Additional cost: $35-50/month (minimal) or $350+/month (standard)

**Recommendation:** Use **minimal scale-to-zero deployment**
```bash
export PROJECT_ID="vaultmesh-473618"
export REGION="europe-west3"  # Same region as your workstation
export USE_AUTOPILOT=true
./deploy-gcp-minimal.sh
```

---

### Option 2: Deploy to Cloud Run Instead

**What it does:**
- Deploy VaultMesh services to Cloud Run (serverless)
- No GKE cluster needed
- Same pattern as your existing ai-companion-proxy and portal

**Pros:**
- ✅ Simpler (no K8s management)
- ✅ Serverless scaling
- ✅ Pay-per-request
- ✅ Matches your existing architecture

**Cons:**
- ⚠️ Less control than K8s
- ⚠️ No KEDA scale-to-zero
- ⚠️ Different deployment model

**Not yet implemented in this repo** (but we could create it)

---

### Option 3: Use Existing Infrastructure

**Possible integration:**
1. Deploy services to your existing workstation
2. Use Docker Compose locally
3. Port-forward for development

**Best for:** Local development only

---

## Security Audit

✅ **Good:**
- Secrets stored in Secret Manager (not hardcoded)
- Service accounts properly configured
- Receipts bucket configured
- Workload Identity ready

⚠️ **To Consider:**
- Workstation has external IP (34.179.146.101) - ensure SSH is locked down
- Default firewall rules are permissive - consider restricting

---

## Pre-Deployment Checklist

Before deploying VaultMesh services:

- [x] GCP project verified (vaultmesh-473618)
- [x] APIs enabled
- [x] Secrets configured
- [x] Artifact Registry ready
- [x] Receipts bucket exists
- [x] Service accounts configured
- [ ] **Decision:** GKE or Cloud Run?
- [ ] **Decision:** Minimal or standard deployment?
- [ ] **Decision:** Same region (europe-west3) or different?

---

## Recommended Next Steps

### For GKE Minimal Deployment (Recommended)

1. **Set region to match existing resources:**
   ```bash
   export PROJECT_ID="vaultmesh-473618"
   export REGION="europe-west3"  # Same as workstation
   export CLUSTER_NAME="vaultmesh-minimal"
   export USE_AUTOPILOT=true
   ```

2. **Run minimal deployment:**
   ```bash
   ./deploy-gcp-minimal.sh
   ```

3. **What it will do:**
   - Create GKE Autopilot cluster in europe-west3
   - Install KEDA for scale-to-zero
   - Deploy psi-field and scheduler (replicas=0)
   - Set up Pub/Sub topics
   - Configure Workload Identity
   - Use existing secrets from Secret Manager

4. **Cost impact:**
   - Current: ~$120-195/month
   - After deployment (idle): ~$155-245/month (+$35-50)
   - After deployment (active): ~$250-400/month (depends on usage)

---

## Questions to Answer

1. **Do you want to keep the existing Cloud Run services?**
   - Yes → Deploy GKE alongside (separate infrastructure)
   - No → We can migrate Cloud Run to GKE

2. **Region preference?**
   - europe-west3 (matches your workstation) ← Recommended
   - us-central1 (more services available)
   - Other?

3. **Deployment type?**
   - Minimal scale-to-zero (recommended) → ~$35-50/month idle
   - Standard always-on → ~$350-450/month

4. **Use existing secrets?**
   - Yes → We'll configure K8s to use Secret Manager
   - No → Create new secrets

---

## Summary

**Your GCP project is already active with:**
- 2 Cloud Run services running
- 1 development workstation (e2-standard-4)
- 6 secrets configured
- Receipts bucket ready
- Multiple service accounts set up

**No conflicts expected** - we can deploy VaultMesh services to GKE without affecting existing infrastructure.

**Total cost would be:** $155-595/month (depending on deployment type + existing resources)

---

**Ready to proceed?** Tell me:
1. Which deployment? (minimal or standard)
2. Which region? (europe-west3 or other)
3. Keep existing Cloud Run services? (yes or no)
