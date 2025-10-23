#!/usr/bin/env bash
##
## VaultMesh Migration Engine (Alchemical Phases)
## Idempotent, receipted, git-aware repository reorganization
##
set -euo pipefail

MODE="${1:---dry-run}"     # --dry-run | --apply
TS="${VAULTMESH_TS:-2025-10-23}"
RECEIPTS_DIR="archive/completion-records/${TS}"
LOG_DIR=".vaultmesh/migration-logs"
RECEIPT="${RECEIPTS_DIR}/MIGRATION_RECEIPT_${TS}.log"

is_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
mv_cmd() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if is_git; then
    git mv -k "$src" "$dst" 2>/dev/null || mv "$src" "$dst"
  else
    mv "$src" "$dst"
  fi
}

note() { echo ">> $*"; }
plan=()

queue() {
  [[ -e "$1" ]] && plan+=("$1|$2")
}

echo "🜂 VaultMesh Migration Engine"
echo "   Mode: $MODE"
echo "   Phase: Nigredo (Dissolution of Clutter)"
echo

# ========== PHASE: NIGREDO (P0) ==========
# Archive root completion/status docs

note "Queuing Nigredo operations..."

for f in \
  GCP_CONFIDENTIAL_COMPUTE_DELIVERY_COMPLETE.md \
  GCP_CONFIDENTIAL_COMPUTE_FILE_TREE.md \
  INFRASTRUCTURE_FILE_TREE.md \
  RUBEDO_SEAL_COMPLETE.md \
  SYSTEMATIC_KPI_DEPLOYMENT_COMPLETE.md \
  KPI_DEPLOYMENT_STATUS.md \
  PSI_FIELD_POD_DRIFT_ANALYSIS.md \
  V2.2_PRODUCTION_SUMMARY.md \
  VAULTMESH_KPI_DASHBOARD.md \
  VM_GIT_AUDIT_REPORT.md \
  PR_5_REVIEWER_NOTE.md \
  REMEMBRANCER_INITIALIZATION.md \
  REMEMBRANCER_README.md \
; do
  queue "$f" "${RECEIPTS_DIR}/$f"
done

# Status .txt files
queue "C3L_INTEGRATION_SUMMARY.txt" "${RECEIPTS_DIR}/C3L_INTEGRATION_SUMMARY.txt"
queue "✅_V4.0_TESTS_PASSING.txt" "${RECEIPTS_DIR}/✅_V4.0_TESTS_PASSING.txt"

# Operational files
queue "CHECKSUMS.txt" "ops/data/CHECKSUMS.txt"
queue "NAMESERVERS.txt" "infrastructure/aws/NAMESERVERS.txt"

# EKS manifest
queue "eks-aurora-staging.yaml" "infrastructure/aws/eks/aurora-staging.yaml"

# Architecture docs to docs/
mkdir -p docs/architecture docs/security docs/operations docs/guides docs/deployment
queue "ARCHITECTURE.md" "docs/architecture/ARCHITECTURE.md"
queue "DOMAIN_STRATEGY.md" "docs/architecture/DOMAIN_STRATEGY.md"
queue "EVOLUTION_PACK.md" "docs/architecture/EVOLUTION_PACK.md"
queue "THREAT_MODEL.md" "docs/security/THREAT_MODEL.md"

# Operational docs
queue "AWS_EKS_QUICKSTART.md" "docs/operations/AWS_EKS_QUICKSTART.md"
queue "IMMEDIATE_ACTIONS.md" "ops/IMMEDIATE_ACTIONS.md"
queue "OPERATOR_CARD.md" "docs/operations/OPERATOR_CARD.md"

# Feature/guide docs
queue "FASTMCP_INSTALLATION.md" "docs/guides/FASTMCP_INSTALLATION.md"
queue "HUGGINGFACE_DEPLOYMENT_PLAN.md" "docs/guides/HUGGINGFACE_DEPLOYMENT_PLAN.md"
queue "RUBBER_DUCKY_PAYLOAD.md" "docs/deployment/RUBBER_DUCKY_PAYLOAD.md"
queue "MIGRATION.md" "docs/guides/MIGRATION.md"

# Folder migrations
queue "deployment" "archive/deployment-legacy"
queue "docs/gcp" "archive/gcp-docs"
queue "docs/gke" "archive/gke-docs"
queue "artifacts" "archive/test-artifacts"
queue "contracts" "archive/contracts-legacy"
queue "vaultmesh_c3l_package" "packages/c3l"

# Create canonical GCP layout
mkdir -p infrastructure/gcp/{terraform,kubernetes,schemas,docs}
mkdir -p infrastructure/aws/{eks,terraform}

# Move schema (deployment version is canonical per audit)
if [[ -f deployment/gcp-confidential-compute/schemas/readproof-schema.json ]]; then
  queue "deployment/gcp-confidential-compute/schemas/readproof-schema.json" \
        "infrastructure/gcp/schemas/readproof-schema.json"
fi

# Move deployment guide
if [[ -f deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md ]]; then
  queue "deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md" \
        "infrastructure/gcp/docs/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md"
fi

# Terraform: Copy infrastructure/terraform/gcp to canonical location
if [[ -f infrastructure/terraform/gcp/confidential-vm/main.tf ]]; then
  if [[ ! -f infrastructure/gcp/terraform/confidential-vm.tf ]]; then
    note "Copying terraform to canonical location (preserving original for diff)"
    mkdir -p infrastructure/gcp/terraform
    cp infrastructure/terraform/gcp/confidential-vm/main.tf \
       infrastructure/gcp/terraform/confidential-vm.tf
  fi
fi

# K8s: Sync GKE configs if not present
if [[ -d infrastructure/kubernetes/gke && ! -d infrastructure/gcp/kubernetes/gke ]]; then
  note "Syncing GKE kubernetes configs to canonical location"
  mkdir -p infrastructure/gcp/kubernetes
  cp -R infrastructure/kubernetes/gke infrastructure/gcp/kubernetes/
fi

# ========== PHASE: ALBEDO (P1) - Service Standardization ==========
# (These are safe structural changes that don't move content)

note "Queuing Albedo operations (service standardization)..."

for svc in services/*; do
  if [[ -d "$svc" ]]; then
    # Rename test -> tests
    if [[ -d "$svc/test" && ! -d "$svc/tests" ]]; then
      queue "$svc/test" "$svc/tests"
    fi

    # Create k8s/ if missing
    if [[ ! -d "$svc/k8s" ]]; then
      mkdir -p "$svc/k8s"
    fi
  fi
done

# ========== Execution ==========

mkdir -p "$LOG_DIR" "$RECEIPTS_DIR"

if [[ "$MODE" == "--dry-run" ]]; then
  note "DRY RUN — Planned operations (${#plan[@]} total):"
  echo
  for op in "${plan[@]}"; do
    IFS="|" read -r s d <<< "$op"
    echo "  mv '$s' -> '$d'"
  done
  echo
  note "Execute with: $0 --apply"
  exit 0
fi

# Apply migrations
note "Applying ${#plan[@]} operations..."
touch "$RECEIPT"

for op in "${plan[@]}"; do
  IFS="|" read -r s d <<< "$op"
  if [[ -e "$s" ]]; then
    note "Moving '$s' -> '$d'"
    mv_cmd "$s" "$d"
    echo "$(date -Iseconds) | $s -> $d" >> "$RECEIPT"
  else
    note "Skipping '$s' (already moved or doesn't exist)"
  fi
done

# .gitignore hardening (idempotent)
append_gitignore() {
  local pat="$1"
  grep -qxF "$pat" .gitignore 2>/dev/null || echo "$pat" >> .gitignore
}

note "Hardening .gitignore..."
append_gitignore "dist/"
append_gitignore "logs/"
append_gitignore "out/"
append_gitignore "secrets/"
append_gitignore ".vaultmesh/migration-logs/"

# Create GCP infrastructure README
if [[ ! -f infrastructure/gcp/README.md ]]; then
  note "Creating infrastructure/gcp/README.md..."
  cat > infrastructure/gcp/README.md <<'EOF'
# GCP Confidential Computing Infrastructure

**Canonical source for all GCP deployment configurations.**

## Contents

- `terraform/` — Confidential VM IaC (Intel TDX + H100 GPUs)
- `kubernetes/` — GKE cluster configs + GPU node pools
- `schemas/` — ReadProof schema definitions
- `docs/` — Deployment guides + troubleshooting

## Quick Start

1. **Terraform:** `cd terraform && terraform init && terraform plan`
2. **GKE Cluster:** See `kubernetes/gke/README.md`
3. **Deployment Guide:** See `docs/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md`

## Version History

See `archive/gcp-docs/` and `archive/gke-docs/` for historical configs.

**Astra inclinant, sed non obligant. 🜂**
EOF
fi

# Create AWS infrastructure structure
if [[ ! -f infrastructure/aws/README.md ]]; then
  note "Creating infrastructure/aws/README.md..."
  cat > infrastructure/aws/README.md <<'EOF'
# AWS Infrastructure

**EKS cluster configurations and supporting infrastructure.**

## Contents

- `eks/` — EKS cluster manifests
- `terraform/` — AWS infrastructure as code

## Active Cluster

- **aurora-staging** (eu-west-1) — Primary staging environment

## Deployment

See `eks/aurora-staging.yaml` for cluster configuration.

**Astra inclinant, sed non obligant. 🜂**
EOF
fi

echo
note "✅ Nigredo complete!"
note "   Receipt: $RECEIPT"
note "   Operations applied: ${#plan[@]}"
echo
note "Next steps:"
note "  1. Review changes: git status"
note "  2. Run Tem Guardian: make guardian"
note "  3. Commit: git commit -m 'chore(nigredo): canonicalize infrastructure + archive clutter'"
echo
note "Astra inclinant, sed non obligant. 🜂"
