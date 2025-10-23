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
