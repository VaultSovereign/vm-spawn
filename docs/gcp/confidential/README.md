# GCP Confidential Compute (VaultMesh)

This directory contains the canonical GCP Confidential Compute documentation and IaC for VaultMesh.

- Quickstart: `docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md`
- Complete Status: `docs/gcp/confidential/GCP_CONFIDENTIAL_VM_COMPLETE_STATUS.md`
- Deployment Status: `docs/gcp/confidential/GCP_CONFIDENTIAL_VM_DEPLOYMENT_STATUS.md`
- Terraform (standalone VM): `docs/gcp/confidential/gcp-confidential-vm.tf`
- ReadProof schema: `docs/gcp/confidential/gcp-confidential-vm-proof-schema.json`

Notes:
- The schema used by automation lives at `deployment/gcp-confidential-compute/schemas/readproof-schema.json` (source of truth). Keep this and the doc copy in sync.
- GKE manifests are under `docs/gke/confidential/`.

Related:
- Guide: `deployment/guides/GCP_CONFIDENTIAL_COMPUTE_GUIDE.md`
- Terraform (module): `infrastructure/terraform/gcp/confidential-vm/`
- GKE infra READMEs: `infrastructure/kubernetes/gke/`
