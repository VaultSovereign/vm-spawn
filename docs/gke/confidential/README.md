# GKE (Confidential + GPUs)

Canonical manifests and references for running VaultMesh on GKE with Confidential Nodes and H100 GPUs:

- Cluster config: `docs/gke/confidential/gke-cluster-config.yaml`
- GPU node pool: `docs/gke/confidential/gke-gpu-nodepool.yaml`
- Workload (attestation): `docs/gke/confidential/gke-vaultmesh-deployment.yaml`
- KEDA scaler (Pub/Sub): `docs/gke/confidential/gke-keda-scaler.yaml`

Usage examples are in `docs/gcp/confidential/GCP_CONFIDENTIAL_QUICKSTART.md` and status docs under the same folder.

