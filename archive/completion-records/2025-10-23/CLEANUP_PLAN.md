# 🧹 Cleanup & Organization Plan

**Date:** 2025-10-23  
**Status:** Ready to Execute  
**Scope:** Remove duplicate/legacy docs, organize GCP infrastructure

---

## 📊 Current State Analysis

### **Root-Level Files to Archive** (Legacy Milestone Docs)
These files document historical phases but clutter the root:

```
ARCHIVE_RITE_PHASE_V_COMPLETE.md          → archive/
AURORA_DEPLOYMENT_STATUS.md               → archive/
DEPLOYMENT_EXECUTION_LOG.md               → archive/
DEPLOYMENT_STATUS_FINAL.md                → archive/
DASHBOARDS_FIXED.md                       → archive/
DOCS_GUARDIANS_INSTALLED.md               → archive/
FINAL_STATUS.md                           → archive/
FINAL_REVENUE_STATUS.md                   → archive/
P0_DEPLOYMENT_COMPLETE.md                 → archive/
P0_EXECUTION_CHECKLIST.md                 → archive/
PHASE_V_IMPLEMENTATION_SUMMARY.md         → archive/
PHASE_V_MISSION_ACCOMPLISHED.md           → archive/
PSI_FIELD_DASHBOARD_FIXED.md              → archive/
PSI_FIELD_DEPLOYED.md                     → archive/
PSI_FIELD_STATUS.md                       → archive/
REVENUE_ACTIVATED_FINAL.md                → archive/
REVENUE_TIER_1_ACTIVATED.md               → archive/
VAULTMESH_CLOUD_READY.md                  → archive/
WEEK1_EKS_GUIDE.md                        → archive/
WEEK1_KICKOFF.md                          → archive/
WEEK1_SOAK_PROTOCOL.md                    → archive/
```

### **Root-Level Files to Clean** (Status Markers)
These were used for phase tracking but are now redundant:

```
⚡_PHASE2_READY.txt              → DELETE
⚡_PHASE3_COMPLETE.txt           → DELETE
⚡_V4.0_KICKOFF_DEPLOYED.txt     → DELETE
✅_V4.0_TESTS_PASSING.txt        → DELETE
🎉_V2.3.0_DEPLOYED.txt           → DELETE
🎉_V4.0_FOUNDATION_COMPLETE.txt  → DELETE
🎉_V4.0_MERGED_TO_MAIN.txt       → DELETE
🎖️_PHASE2_COMPLETE_TESTED.txt    → DELETE
🎖️_PRODUCTION_SEALED.txt         → DELETE
🎖️_V3.0_DOCUMENTATION_COMPLETE.txt → DELETE
📚_V4.0_DOCUMENTATION_COMPLETE.txt → DELETE
🚀_DEPLOYMENT_SUCCESS.txt        → DELETE
🛡️_PHASE1_HARDENING_COMPLETE.txt → DELETE
🛡️_PHASE1_PUSHED.txt             → DELETE
🜂_RUBEDO_COMPLETE.txt           → DELETE
🜂_V3.0_PUSHED.txt               → DELETE
🦆_V2.3.0_DUCKY_WIRED.txt        → DELETE
```

### **GCP Infrastructure Files** (New - Keep in Proper Structure)

**Current Location (now canonical):**
```
docs/gcp/confidential/gcp-confidential-vm.tf
docs/gcp/confidential/gcp-confidential-vm-proof-schema.json
docs/gcp/confidential/GCP_CONFIDENTIAL_VM_DEPLOYMENT_STATUS.md
docs/gcp/confidential/GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md
docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md
docs/gke/confidential/gke-cluster-config.yaml
docs/gke/confidential/gke-gpu-nodepool.yaml
docs/gke/confidential/gke-vaultmesh-deployment.yaml
docs/gke/confidential/gke-keda-scaler.yaml
GCP_CONFIDENTIAL_COMPUTE_DELIVERY_COMPLETE.md
GCP_CONFIDENTIAL_COMPUTE_FILE_TREE.md
INFRASTRUCTURE_FILE_TREE.md
```

**Target Location (Organized):**
```
infrastructure/gcp/
├── terraform/
│   ├── confidential-vm.tf          (Layer 1: IaC)
│   └── variables.tf
├── kubernetes/
│   ├── cluster-config.yaml         (Layer 2: GKE)
│   ├── gpu-nodepool.yaml
│   ├── vaultmesh-deployment.yaml
│   └── keda-scaler.yaml
├── schemas/
│   └── readproof-schema.json       (Proof format)
└── docs/
    ├── README.md                   (Overview)
    ├── DEPLOYMENT_GUIDE.md         (Step-by-step)
    ├── QUICKSTART.md               (5-min deploy)
    ├── TROUBLESHOOTING.md
    └── COST_ANALYSIS.md
```

---

## 🎯 Cleanup Actions

### **Phase 1: Archive Legacy Docs** (Safe - No Deletions)
Move historical documentation to `archive/completion-records/20251023/`:

```bash
# Already have structure:
archive/
├── completion-records/
│   └── 20251023/          ← New folder for v4.1 completion docs

# Move these files:
mv ARCHIVE_RITE_PHASE_V_COMPLETE.md archive/completion-records/20251023/
mv AURORA_DEPLOYMENT_STATUS.md archive/completion-records/20251023/
# ... etc
```

**Rationale:** 
- These docs are valuable for history but clutter root
- Searchable in archive/ if needed
- Frees root directory for active deployment docs

### **Phase 2: Delete Status Markers** (Safe - Symbolic Only)
Remove emoji/status marker files:

```bash
rm -f ⚡_*.txt 🎉_*.txt 🎖️_*.txt 📚_*.txt 🚀_*.txt 🛡️_*.txt 🜂_*.txt 🦆_*.txt
```

**Rationale:**
- These were phase tracking files
- Phase complete, no longer needed
- Free up directory listing

### **Phase 3: Organize GCP Infrastructure**
Create proper folder structure (docs already organized under `docs/gcp/confidential` and `docs/gke/confidential`):

```bash
# Create folders
mkdir -p infrastructure/gcp/{terraform,kubernetes,schemas,docs}

# Move/Copy Terraform files (optional; docs copy lives under docs/gcp/confidential)
mv docs/gcp/confidential/gcp-confidential-vm.tf infrastructure/gcp/terraform/confidential-vm.tf
cat > infrastructure/gcp/terraform/variables.tf << 'EOF'
variable "project_id" {...}
variable "region" {...}
# ... etc
EOF

# Move K8s files (optional; docs copies live under docs/gke/confidential)
mv docs/gke/confidential/*.yaml infrastructure/gcp/kubernetes/
mv docs/gcp/confidential/gcp-confidential-vm-proof-schema.json infrastructure/gcp/schemas/readproof-schema.json

# Move/Create docs (optional; canonical docs live under docs/gcp/confidential)
mv docs/gcp/confidential/GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md infrastructure/gcp/docs/DEPLOYMENT_GUIDE.md
mv docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md infrastructure/gcp/docs/QUICKSTART.md
cat > infrastructure/gcp/docs/README.md << 'EOF'
# GCP Confidential Computing Infrastructure
# (New organized structure)
EOF
```

### **Phase 4: Create Index** (Navigation)
Create `infrastructure/README.md`:

```markdown
# Infrastructure as Code

Organized deployment configurations for VaultMesh across cloud providers.

## Supported Platforms

- **GCP** (Confidential Computing with Intel TDX + H100 GPUs)
- **AWS** (EKS with spot instances + auto-scaling)
- **Akash** (Decentralized GPU marketplace)

## GCP Confidential Computing

📁 `gcp/` — Complete deployment for GCP Confidential VMs

- `terraform/` — IaC for A3 Confidential VMs
- `kubernetes/` — GKE cluster + workload manifests
- `schemas/` — ReadProof proof format definitions
- `docs/` — Deployment guides, troubleshooting, cost analysis

**Quick Start:**
See `gcp/docs/QUICKSTART.md` (5 minutes to running inference)

...
```

---

## 📁 Target Directory Structure

After cleanup:

```
vm-spawn/
│
├── 📋 Core Documentation (Root Level - Clean)
│   ├── README.md                    ← Main entry point
│   ├── START_HERE.md                ← Quick orientation
│   ├── AGENTS.md                    ← AI agent guide
│   ├── SECURITY.md                  ← Security model
│   ├── LICENSE
│   └── VERSION_TIMELINE.md          ← Complete history
│
├── 📚 DAO Governance (Optional Plugin)
│   └── DAO_GOVERNANCE_PACK/         ← Policies + procedures
│
├── 🛠️ Infrastructure as Code
│   └── infrastructure/
│       ├── README.md                ← Overview
│       ├── gcp/
│       │   ├── README.md            ← GCP guide
│       │   ├── terraform/
│       │   │   ├── confidential-vm.tf
│       │   │   ├── variables.tf
│       │   │   └── outputs.tf
│       │   ├── kubernetes/
│       │   │   ├── cluster-config.yaml
│       │   │   ├── gpu-nodepool.yaml
│       │   │   ├── vaultmesh-deployment.yaml
│       │   │   └── keda-scaler.yaml
│       │   ├── schemas/
│       │   │   └── readproof-schema.json
│       │   └── docs/
│       │       ├── DEPLOYMENT_GUIDE.md
│       │       ├── QUICKSTART.md
│       │       ├── TROUBLESHOOTING.md
│       │       ├── COST_ANALYSIS.md
│       │       └── FAQ.md
│       ├── aws/
│       │   ├── README.md
│       │   └── ... (existing EKS config)
│       └── akash/
│           ├── README.md
│           └── ... (future: decentralized GPU)
│
├── 🧠 Spawn Elite + Remembrancer
│   ├── spawn.sh                     ← Main orchestrator
│   ├── generators/                  ← 11 modular generators
│   ├── ops/                         ← Cryptographic memory layer
│   ├── services/                    ← Production services
│   └── templates/                   ← Base templates
│
├── 📖 Technical Documentation
│   └── docs/
│       ├── REMEMBRANCER.md          ← Canonical memory index
│       ├── REMEMBRANCER_PHASE_V.md  ← Federation semantics
│       ├── FEDERATION_PROTOCOL.md   ← Wire protocol
│       ├── COVENANT_SIGNING.md      ← GPG guide
│       ├── COVENANT_TIMESTAMPS.md   ← RFC 3161 guide
│       ├── adr/                     ← Architectural decisions
│       └── ... (other reference docs)
│
├── 📦 Archive (Historical)
│   └── archive/
│       ├── completion-records/
│       │   └── 20251023/            ← v4.1 completion docs
│       │       ├── PHASE_V_IMPLEMENTATION_SUMMARY.md
│       │       ├── AURORA_DEPLOYMENT_STATUS.md
│       │       └── ... (other v4.1 docs)
│       └── development-docs/        ← Historical planning
│
└── 🧪 Testing & Examples
    ├── tests/
    ├── examples/
    ├── SMOKE_TEST.sh
    └── Makefile
```

---

## ✅ Cleanup Checklist

- [ ] **Archive old docs** (21 files → `archive/completion-records/20251023/`)
- [ ] **Delete status markers** (17 emoji files → gone)
- [ ] **Create infrastructure/ folder structure** (3 folders + 4 subfolders)
- [ ] **Move GCP files** to proper locations (7 files)
- [ ] **Create index documentation** (`infrastructure/README.md`, `infrastructure/gcp/README.md`)
- [ ] **Update root README.md** to reference new structure
- [ ] **Verify no broken links** in documentation
- [ ] **Commit cleanup** with message "chore: organize infrastructure and archive v4.1 docs"

---

## 🎯 Expected Results

### **Before Cleanup**
```
Root directory: 120+ files
- Duplicates: GCP files scattered in docs/ + root
- Clutter: 17 status marker files
- Mix: Active + archived docs together
- Navigation: Confusing for new users
```

### **After Cleanup**
```
Root directory: 25-30 files
- Clean: Only active docs + entry points
- Organized: infrastructure/ for all IaC
- Archived: Historical docs in archive/
- Navigation: Clear START_HERE → docs → infrastructure/
- 100% backward compatible: Old links still work via redirects
```

---

## 🔄 Backward Compatibility

**All old paths will still work:**
```bash
# Doc path (canonical)
docs/gcp/confidential/gcp-confidential-vm.tf

# New path (primary)
infrastructure/gcp/terraform/confidential-vm.tf

# We can create symlinks for transition:
ln -s ../../../infrastructure/gcp/terraform/confidential-vm.tf docs/gcp/confidential/gcp-confidential-vm.tf
```

---

## 📋 Execution Steps

Ready to execute on your command. Would you like me to:

1. **Just archive the old docs** (no deletions)?
2. **Create the new structure** (no moves)?
3. **Do full cleanup** (organize + move + delete)?

---

**Status:** ✅ Plan Ready  
**Confidence:** 10/10  
**Risk Level:** Low (all changes reversible via git)  
**Estimated Time:** 10 minutes
