# VaultMesh Confidential (Helm Chart)

Deploys a VaultMesh workload pinned to confidential compute + GPU nodes with optional KEDA autoscaling.

Prerequisites
- Kubernetes cluster with confidential nodes + GPU node pool (e.g., GKE A3)
- KEDA installed if autoscaling is enabled (`helm repo add kedacore https://kedacore.github.io/charts && helm install keda kedacore/keda -n keda --create-namespace`)
- Pub/Sub subscription available if using KEDA `gcp-pubsub` trigger

Quick start (dry-run)
```bash
helm upgrade --install vaultmesh charts/vaultmesh-confidential \
  -f charts/vaultmesh-confidential/values-example.yaml \
  --namespace aurora-staging --create-namespace \
  --dry-run --debug
```

Install
```bash
helm upgrade --install vaultmesh charts/vaultmesh-confidential \
  -f charts/vaultmesh-confidential/values-example.yaml \
  --namespace aurora-staging --create-namespace
```

Key values
- `image.repository` / `image.tag` — workload image
- `readProof.endpoint` — VaultMesh ReadProof endpoint
- `nodeSelector` — must target your confidential GPU pool (e.g., `gpu: h100`, `confidential: "true"`)
- `tolerations` — match your GPU node taints (e.g., `gpu=true:NoSchedule`)
- `keda.*` — Pub/Sub subscription, scale bounds, cooldown
- `resources.limits.nvidia.com/gpu` — number of GPUs per pod (default: 1)

Notes
- This chart is a thin wrapper around the docs manifests at `docs/gke/confidential/` with templated values.
- Ensure your cluster has the NVIDIA device plugin installed.
- If you use the GitHub Actions deploy workflow, set `KUBE_CONFIG_DATA` (base64 kubeconfig) as a repository secret.

