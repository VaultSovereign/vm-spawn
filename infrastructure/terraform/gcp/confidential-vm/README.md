# Terraform configuration for GCP Confidential A3 VM with H100 GPUs

## Usage

```bash
cd infrastructure/terraform/gcp/confidential-vm

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="project_id=$(gcloud config get-value project)"

# Apply deployment
terraform apply -var="project_id=$(gcloud config get-value project)"

# Verify deployment
gcloud compute instances describe vaultmesh-confidential-a3 \
  --zone=us-central1-a \
  --format="value(confidential_instance_config)"

# SSH into instance
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a

# Check attestation
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="cat /var/lib/vaultmesh/gcp_attestation_quote.json"

# View Docker logs
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="docker logs vaultmesh-agent"
```

## Architecture

```
┌────────────────────────────────────────┐
│ Confidential A3 VM (8x H100 GPUs)      │
├────────────────────────────────────────┤
│ • Intel TDX enabled                     │
│ • Shielded boot + vTPM                  │
│ • NVIDIA drivers + Docker               │
│ • VaultMesh agent daemon                │
│ • GPU drivers + CUDA                    │
└────────────────────────────────────────┘
            ↓
┌────────────────────────────────────────┐
│ TEE Attestation Flow                    │
├────────────────────────────────────────┤
│ 1. Startup script captures TDX quote    │
│ 2. Stored in /var/lib/vaultmesh/       │
│ 3. VaultMesh agent reads & posts proof │
│ 4. ReadProof includes attestation      │
│ 5. Merkle audit trail records proof    │
└────────────────────────────────────────┘
```

## Cost Estimation

| Item | Cost/Hour | Cost/Day | Cost/Month |
|------|-----------|----------|------------|
| A3-highgpu-8g (on-demand) | $11.52 | $276.48 | $8,294.40 |
| 8x H100 (on-demand) | $32.00 | $768.00 | $23,040.00 |
| Network (egress) | $0.05 | $1.20 | $36.00 |
| **Total** | **$43.57** | **$1,045.68** | **$31,370.40** |

**Notes:**
- This is for always-on compute
- Use GKE with KEDA for cost-effective workloads (94% savings)
- Standalone VMs better for continuous GPU services

## Troubleshooting

### "Attestation not working"
```bash
# Check attestation tool installation
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="which attestation_verifier"

# Check attestation quote
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="cat /var/lib/vaultmesh/gcp_attestation_quote.json | jq ."
```

### "Docker not running"
```bash
# Check Docker status
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="sudo systemctl status docker"

# Restart Docker
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="sudo systemctl restart docker"
```

### "GPU drivers not loaded"
```bash
# Check NVIDIA drivers
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="nvidia-smi"

# Check kernel module
gcloud compute ssh vaultmesh-confidential-a3 --zone=us-central1-a \
  --command="lsmod | grep nvidia"
```

## Files

- `main.tf` - Primary Terraform configuration
- `README.md` - This file
- See `infrastructure/terraform/gcp/gke-cluster/` for Kubernetes alternative

## Next Steps

1. Deploy this infrastructure
2. Verify attestation in `/var/lib/vaultmesh/gcp_attestation_quote.json`
3. Check VaultMesh agent logs: `docker logs vaultmesh-agent`
4. Record deployment in Remembrancer: `./ops/bin/remembrancer record deploy ...`
5. For scaling workloads, use GKE + KEDA instead (see `infrastructure/kubernetes/gke/`)
