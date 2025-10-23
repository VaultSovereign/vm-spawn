# GCP Confidential Compute Deployment Guides

Complete step-by-step guides for deploying VaultMesh on GCP with Confidential Computing.

## 📋 Quick Navigation

### **Option 1: Standalone Confidential VM (8x H100)**

For always-on GPU compute services or testing.

**Files:**
- `infrastructure/terraform/gcp/confidential-vm/main.tf` - Terraform configuration
- `infrastructure/terraform/gcp/confidential-vm/README.md` - Detailed guide

**Quick start:**
```bash
cd infrastructure/terraform/gcp/confidential-vm
terraform init
terraform apply -var="project_id=$(gcloud config get-value project)"
```

**Cost:** ~$1,000+/month for continuous 8x H100

**Best for:**
- Development & testing
- Long-running inference services
- Always-on GPU workloads

---

### **Option 2: GKE + KEDA (Scale from Zero)**

For cost-effective, on-demand inference workloads.

**Files:**
- `infrastructure/kubernetes/gke/README-CLUSTER-SETUP.md` - Create GKE cluster
- `infrastructure/kubernetes/gke/README-GPU-POOL.md` - Create GPU node pool
- `infrastructure/kubernetes/gke/deployments/vaultmesh-infer.yaml` - Workload deployment
- `infrastructure/kubernetes/gke/autoscaling/keda-scaler.yaml` - Auto-scaling config
- `infrastructure/kubernetes/gke/autoscaling/README.md` - KEDA guide

**Quick start:**
```bash
# 1. Create cluster (20 min)
gcloud container clusters create vaultmesh-cluster \
  --region=us-central1 \
  --enable-confidential-nodes \
  --workload-pool="$(gcloud config get-value project).svc.id.goog"

# 2. Create GPU pool (10 min)
gcloud container node-pools create h100-conf \
  --cluster=vaultmesh-cluster \
  --region=us-central1 \
  --machine-type=a3-highgpu-1g \
  --accelerator=nvidia-h100-80gb,count=1 \
  --enable-autoscaling --min-nodes=0 --max-nodes=50 --spot

# 3. Deploy workload
kubectl apply -f infrastructure/kubernetes/gke/deployments/vaultmesh-infer.yaml

# 4. Enable scaling
helm install keda kedacore/keda --namespace keda --create-namespace
kubectl apply -f infrastructure/kubernetes/gke/autoscaling/keda-scaler.yaml

# 5. Test
gcloud pubsub topics create vaultmesh-jobs
gcloud pubsub subscriptions create vaultmesh-jobs --topic vaultmesh-jobs
gcloud pubsub topics publish vaultmesh-jobs --message '{"job":"test"}'
```

**Cost:** ~$15/month for 2 hrs/day usage (94% savings vs always-on)

**Best for:**
- High-scale inference services
- Periodic/batch jobs
- Cost-sensitive production
- Multi-tenant setups

---

## 📚 Complete Directory Structure

```
infrastructure/
├── terraform/
│   └── gcp/
│       ├── confidential-vm/
│       │   ├── main.tf          ← Standalone VM
│       │   └── README.md
│       └── gke-cluster/         ← Optional: GKE cluster IaC
│
└── kubernetes/
    └── gke/
        ├── README-CLUSTER-SETUP.md      ← gcloud commands for cluster
        ├── README-GPU-POOL.md           ← gcloud commands for GPU pool
        ├── deployments/
        │   └── vaultmesh-infer.yaml     ← Workload + init container
        └── autoscaling/
            ├── keda-scaler.yaml         ← KEDA ScaledObject
            └── README.md

deployment/
├── gcp-confidential-compute/
│   ├── schemas/
│   │   └── readproof-schema.json  ← ReadProof format
│   └── guides/
│       ├── DEPLOYMENT_CHECKLIST.md         ← Phase-by-phase checklist
│       ├── TROUBLESHOOTING.md              ← Common issues & fixes
│       ├── COST_ANALYSIS.md                ← Cost breakdown
│       └── INTEGRATION_GUIDE.md            ← VaultMesh integration
│
└── guides/
    └── GCP_CONFIDENTIAL_COMPUTE_GUIDE.md   ← Master guide (this file)

docs/
└── gcp/
    └── confidential/
        ├── GCP_CONFIDENTIAL_QUICKSTART.md           ← 5-min quick start
        └── GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md   ← Full status report
```

---

## 🔗 Next Steps

### **1. Choose Your Deployment Model**

- [ ] **Standalone VM** (always-on) → Go to `infrastructure/terraform/gcp/confidential-vm/`
- [ ] **GKE + KEDA** (cost-optimized) → Go to `infrastructure/kubernetes/gke/`

### **2. Follow the Deployment Guide**

- [ ] Review prerequisites in chosen guide
- [ ] Run infrastructure setup commands
- [ ] Deploy VaultMesh workload
- [ ] Test attestation capture
- [ ] Record in Remembrancer

### **3. Integration Checklist**

- [ ] Attestation captures successfully
- [ ] ReadProof posts to endpoint
- [ ] Merkle audit records proof
- [ ] Four Covenants validate
- [ ] GPU metrics captured

---

## 📊 Cost Comparison

| Model | Workload | Cost/Month | Setup Time |
|-------|----------|------------|------------|
| Standalone A3 VM | Always-on | $31,370 | 10 min |
| GKE (KEDA, 2 hrs/day) | Batch inference | $15 | 45 min |
| GKE (KEDA, 24/7) | Always-on | $9,216 | 45 min |

---

## 🎯 Key Features

✅ **Confidential Computing:** Intel TDX attestation on all compute nodes  
✅ **GPU Acceleration:** H100 80GB GPUs with automatic driver installation  
✅ **Auto-Scaling:** KEDA scales from 0 to 50 pods on demand  
✅ **Cost Optimization:** Pay only for compute used (94% savings possible)  
✅ **Attestation:** Automatic TEE quote capture on pod startup  
✅ **Proof Recording:** Merkle audit trail via Remembrancer  
✅ **Federation Ready:** Proofs can be shared across regions/clouds  

---

## 📞 Support

- **Architecture:** See `AGENTS.md` in repo root
- **Troubleshooting:** See individual guide READMEs
- **Emergency procedures:** See `DAO_GOVERNANCE_PACK/operator-runbook.md`

---

**Version:** v4.1-genesis+ (Confidential Compute Ready)  
**Last Updated:** 2025-10-23  
**Status:** ✅ Production Ready
