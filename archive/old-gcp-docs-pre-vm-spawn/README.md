# Archived: Pre-Deployment GCP Documents & Scripts

**Archived:** 2025-10-24
**Reason:** Outdated references to old GCP projects and pre-deployment planning docs

---

## What's Here

These documents and scripts were used during planning and initial deployment attempts but are now superseded by the actual vm-spawn deployment.

### Documents (Old Project: vaultmesh-473618)

1. **GCP_CURRENT_STATE_AUDIT.md** - Audit of removed vaultmesh-473618 project
2. **CLEANUP_SUMMARY.md** - Cleanup notes from old project transition
3. **DEPLOY_GCP_QUICKSTART.md** - Pre-deployment quick start guide
4. **DEPLOY_GCP_MINIMAL.md** - Pre-deployment minimal guide
5. **GCP_DEPLOYMENT_GUIDE.md** - Pre-deployment full guide

### Scripts (Old Project References)

1. **continue-deployment.sh** - Referenced vaultmesh-473618
2. **final-status.sh** - Referenced vaultmesh-473618
3. **verify-deployment.sh** - Referenced vaultmesh-473618
4. **check-keda.sh** - Referenced vaultmesh-473618
5. **fix-keda.sh** - Referenced vaultmesh-473618

---

## Current Documentation

**Primary Reference:**
- [`GCP_DEPLOYMENT_STATUS.md`](../../GCP_DEPLOYMENT_STATUS.md) - Current deployment status

**Current Project:**
- Project ID: `vm-spawn`
- Project Number: 572946311311
- Cluster: `vaultmesh-minimal` (GKE Autopilot)
- Region: `us-central1`
- Deployment Date: 2025-10-24

**Active Scripts:**
- [`setup-cloudflare-dns.sh`](../../setup-cloudflare-dns.sh) - Updated for vm-spawn
- [`wait-for-ingress.sh`](../../wait-for-ingress.sh) - Current deployment helper
- [`deploy-gcp-minimal.sh`](../../deploy-gcp-minimal.sh) - Main deployment script

---

## What Changed

### Old Projects (Removed/Inaccessible)
- ❌ `vaultmesh-473618` - Original project, removed by user
- ❌ `690790288771` - Project number attempted but not accessible

### Current Project (Active)
- ✅ `vm-spawn` (572946311311) - Successfully deployed Oct 24, 2025

---

## Why These Were Archived

1. **Project Migration**: User removed old vaultmesh-473618 project
2. **Prevent Confusion**: Multiple docs with different project IDs caused drift
3. **Pre-Deployment Obsolete**: Planning docs no longer needed after actual deployment
4. **Script Updates**: All active scripts updated to reference vm-spawn

---

## What Was Updated (Not Archived)

These files were updated with correct vm-spawn references:
- ✅ `setup-cloudflare-dns.sh` - Line 25 updated to vm-spawn
- ✅ `k8s/deployments.yaml` - Updated all image paths and project IDs
- ✅ `k8s/ingress.yaml` - Updated service ports
- ✅ `GCP_DEPLOYMENT_STATUS.md` - Current deployment documentation

---

**Status:** All drift removed, single source of truth established
**Reference:** See [`CLEANUP_GCP_DOCS_2025-10-24.md`](../../CLEANUP_GCP_DOCS_2025-10-24.md) for full cleanup report
