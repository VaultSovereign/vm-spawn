# VaultMesh GCP Confidential Compute - File Tree Organization

**Date:** 2025-10-23  
**Version:** v4.1-genesis+ (Confidential Compute Ready)  
**Status:** ✅ Complete & Organized

---

## 📁 Complete File Structure

```
vm-spawn/
│
├── 🗂️ infrastructure/
│   │
│   ├── 📂 terraform/
│   │   └── 📂 gcp/
│   │       ├── 📂 confidential-vm/
│   │       │   ├── main.tf                    ✅ Standalone A3 VM with H100
│   │       │   └── README.md                  ✅ Setup & troubleshooting guide
│   │       └── 📂 gke-cluster/
│   │           └── (Optional: Terraform IaC for GKE)
│   │
│   └── 📂 kubernetes/
│       └── 📂 gke/
│           ├── README-CLUSTER-SETUP.md       ✅ gcloud: Create cluster
│           ├── README-GPU-POOL.md            ✅ gcloud: Create GPU node pool
│           ├── 📂 deployments/
│           │   ├── vaultmesh-infer.yaml      ✅ Pod with attestation capture
│           │   └── (Stateless inference service)
│           └── 📂 autoscaling/
│               ├── keda-scaler.yaml          ✅ KEDA ScaledObject (0→50 pods)
│               └── README.md                  ✅ KEDA configuration & tuning
│
├── 🗂️ deployment/
│   │
│   ├── 📂 gcp-confidential-compute/
│   │   ├── 📂 schemas/
│   │   │   └── readproof-schema.json         ✅ ReadProof JSON Schema
│   │   └── (Configuration & schemas)
│   │
│   └── 📂 guides/
│       ├── GCP_CONFIDENTIAL_COMPUTE_GUIDE.md ✅ Master deployment guide
│       ├── (Quickstart now in docs/gcp/confidential)
│       └── (Deployment documentation)
│
├── 📂 docs/
│   ├── gcp/
│   │   └── confidential/
│   │       ├── gcp-confidential-vm.tf                ✅ Terraform (docs copy)
│   │       ├── gcp-confidential-vm-proof-schema.json ✅ ReadProof schema (docs copy)
│   │       ├── GCP_CONFIDENTIAL_VM_DEPLOYMENT_STATUS.md
│   │       ├── GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md
│   │       └── GCP_CONFIDENTIAL_QUICKSTART.md
│   └── gke/
│       └── confidential/
│           ├── gke-cluster-config.yaml               ✅ Cluster config (docs copy)
│           ├── gke-gpu-nodepool.yaml                 ✅ GPU node pool (docs copy)
│           ├── gke-vaultmesh-deployment.yaml         ✅ Workload manifest (docs copy)
│           └── gke-keda-scaler.yaml                  ✅ KEDA scaler (docs copy)
│
├── 📂 ops/ (existing VaultMesh tools)
│   ├── bin/
│   │   ├── remembrancer                     ✅ Record deployments
│   │   ├── genesis-seal                     ✅ Seal artifacts
│   │   └── ... (other tools)
│   └── ...
│
├── README.md (main project)
├── AGENTS.md (AI agent guide)
└── ... (other project files)
```

---

## 🎯 Quick Reference by Use Case

### **I want to deploy Confidential VMs (always-on)**

```
📍 Start here: infrastructure/terraform/gcp/confidential-vm/

Files you need:
  1. main.tf           ← Terraform configuration
  2. README.md         ← Setup instructions

Commands:
  cd infrastructure/terraform/gcp/confidential-vm
  terraform init
  terraform apply -var="project_id=$(gcloud config get-value project)"
```

---

### **I want to deploy GKE with autoscaling (cost-optimized)**

```
📍 Start here: infrastructure/kubernetes/gke/

Files you need (in order):
  1. README-CLUSTER-SETUP.md     ← Create cluster (gcloud commands)
  2. README-GPU-POOL.md          ← Create GPU pool (gcloud commands)
  3. deployments/vaultmesh-infer.yaml    ← Deploy workload (kubectl)
  4. autoscaling/keda-scaler.yaml        ← Enable KEDA scaling (kubectl)
  5. autoscaling/README.md       ← KEDA tuning

Commands:
  # Step 1: Cluster
  gcloud container clusters create vaultmesh-cluster ...
  
  # Step 2: GPU Pool
  gcloud container node-pools create h100-conf ...
  
  # Step 3: Workload
  kubectl apply -f infrastructure/kubernetes/gke/deployments/vaultmesh-infer.yaml
  
  # Step 4: Scaling
  helm install keda kedacore/keda --namespace keda --create-namespace
  kubectl apply -f infrastructure/kubernetes/gke/autoscaling/keda-scaler.yaml
```

---

### **I want to understand the architecture**

```
📍 Start here: deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md

Then read:
  - AGENTS.md (general architecture)
  - docs/FEDERATION_PROTOCOL.md (federation)
  - docs/COVENANT_TIMESTAMPS.md (RFC 3161 proofs)
```

---

### **I want the 5-minute quick start**

```
📍 Read: docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md
```

---

## 🔄 Directory Organization Principles

| Layer | Directory | Purpose |
|-------|-----------|---------|
| **IaC** | `infrastructure/terraform/` | Terraform configurations (providers: gcp, aws, azure) |
| **Orchestration** | `infrastructure/kubernetes/` | K8s manifests (clouds: gke, eks, aks) |
| **Deployment** | `deployment/gcp-confidential-compute/` | GCP-specific schemas & configurations |
| **Guides** | `deployment/guides/` | Step-by-step deployment procedures |
| **Tools** | `ops/bin/` | CLI tools (remembrancer, genesis-seal, etc.) |
| **Docs** | `docs/` | Architecture & protocol documentation |

---

## ✅ File Checklist

### **New Organized Files (Recommended)**

- [x] `infrastructure/terraform/gcp/confidential-vm/main.tf` - Clean Terraform
- [x] `infrastructure/terraform/gcp/confidential-vm/README.md` - Setup guide
- [x] `infrastructure/kubernetes/gke/README-CLUSTER-SETUP.md` - Cluster commands
- [x] `infrastructure/kubernetes/gke/README-GPU-POOL.md` - GPU pool commands
- [x] `infrastructure/kubernetes/gke/deployments/vaultmesh-infer.yaml` - Workload
- [x] `infrastructure/kubernetes/gke/autoscaling/keda-scaler.yaml` - KEDA scaler
- [x] `infrastructure/kubernetes/gke/autoscaling/README.md` - KEDA guide
- [x] `deployment/gcp-confidential-compute/schemas/readproof-schema.json` - Schema
- [x] `deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md` - Master guide

### **Documentation Copies (under `docs/`)**

- [x] `docs/gcp/confidential/gcp-confidential-vm.tf`
- [x] `docs/gcp/confidential/gcp-confidential-vm-proof-schema.json`
- [x] `docs/gke/confidential/gke-cluster-config.yaml`
- [x] `docs/gke/confidential/gke-gpu-nodepool.yaml`
- [x] `docs/gke/confidential/gke-vaultmesh-deployment.yaml`
- [x] `docs/gke/confidential/gke-keda-scaler.yaml`

### **Status & Guides (docs)**

- [x] `docs/gcp/confidential/GCP_CONFIDENTIAL_VM_DEPLOYMENT_STATUS.md` - Quick status
- [x] `docs/gcp/confidential/GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md` - Full guide
- [x] `docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md` - 5-min reference

---

## 🚀 Migration Guide

If you have existing deployments using the old paths in `docs/`:

### **For Terraform:**
```bash
# Old path
cd docs
terraform apply

# New path (recommended)
cd infrastructure/terraform/gcp/confidential-vm
terraform apply

# They use the same Terraform state, just organized better
```

### **For Kubernetes:**
```bash
# Doc copy (works)
kubectl apply -f docs/gke/confidential/gke-vaultmesh-deployment.yaml

# New commands (recommended)
kubectl apply -f infrastructure/kubernetes/gke/deployments/vaultmesh-infer.yaml

# Same YAML, better organized
```

---

## 📊 Statistics

| Category | Count | Status |
|----------|-------|--------|
| Terraform files | 1 | ✅ Main |
| K8s manifests | 2 | ✅ Deployments + KEDA |
| README guides | 4 | ✅ Setup + GPU pool + KEDA + master |
| JSON schemas | 1 | ✅ ReadProof |
| Total config files | 8 | ✅ Production-ready |
| Total guides | 7 | ✅ Comprehensive |

---

## 🎯 Next Steps

### **Immediate (Use What's Here)**

1. ✅ Choose deployment model (VM or K8s)
2. ✅ Follow guide in `infrastructure/`
3. ✅ Deploy infrastructure
4. ✅ Test attestation

### **Short-term (Week 2)**

1. [ ] Deploy second workload (different region/cloud)
2. [ ] Verify federation merge works
3. [ ] Set up monitoring & alerting
4. [ ] Document runbook

### **Medium-term (Month 1)**

1. [ ] Multi-region failover
2. [ ] On-chain proof anchoring
3. [ ] Automated covenant validation in CI
4. [ ] Public transparency index

---

## 📚 Documentation Map

```
Quick Start (5 min)
└─ docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md
   
Full Architecture (30 min)
├─ AGENTS.md
└─ deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md

Implementation (2-3 hours)
├─ infrastructure/terraform/gcp/confidential-vm/README.md
└─ infrastructure/kubernetes/gke/
   ├─ README-CLUSTER-SETUP.md
   ├─ README-GPU-POOL.md
   ├─ deployments/
   └─ autoscaling/README.md

Reference
├─ deployment/gcp-confidential-compute/schemas/readproof-schema.json
├─ docs/FEDERATION_PROTOCOL.md
├─ docs/COVENANT_TIMESTAMPS.md
└─ ops/bin/remembrancer (tool)
```

---

## 🏆 Quality Checklist

- [x] All files properly organized by layer
- [x] Clear directory structure (IaC / Orchestration / Deployment / Guides)
- [x] Comprehensive README files for each section
- [x] Working examples in `infrastructure/`
- [x] Schemas in `deployment/gcp-confidential-compute/schemas/`
- [x] Guides in `deployment/guides/`
- [x] Cross-references between files
- [x] Troubleshooting guides included
- [x] Cost analysis provided
- [x] Integration with Remembrancer documented

---

## ✨ Key Features

✅ **Modular Organization** - Each layer has clear responsibilities  
✅ **Cloud-Agnostic Structure** - Easy to add AWS/Azure providers  
✅ **Well-Documented** - Guides, READMEs, schemas included  
✅ **Production-Ready** - All files tested and verified  
✅ **Backwards Compatible** - Legacy paths in `docs/` still work  
✅ **Easy Navigation** - Clear index and cross-references  

---

## 📞 File Questions Answered

**Q: Where do I deploy from?**  
A: `infrastructure/terraform/gcp/confidential-vm/` (Terraform) or `infrastructure/kubernetes/gke/` (K8s)

**Q: Where are the Kubernetes manifests?**  
A: `infrastructure/kubernetes/gke/deployments/` and `infrastructure/kubernetes/gke/autoscaling/`

**Q: Where is the ReadProof schema?**  
A: `deployment/gcp-confidential-compute/schemas/readproof-schema.json`

**Q: Where are the guides?**  
A: `deployment/guides/` (master guide) + `infrastructure/*/README*.md` (tool-specific)

**Q: Can I still use the old `docs/` files?**  
A: Yes! They still work. The new structure is just better organized.

---

**Version:** v4.1-genesis+ (Confidential Compute Ready)  
**Date:** 2025-10-23  
**Status:** ✅ COMPLETE & ORGANIZED
