# GKE GPU Node Pool Configuration for H100 Confidential Computing
# This file documents the gcloud commands to create an autoscaling H100 node pool

# Prerequisites:
# - GKE cluster already created (see README-CLUSTER-SETUP.md)
# - Quota for A3-highgpu-1g machines in us-central1
# - Quota for nvidia-h100-80gb GPUs in us-central1
# - PROJECT_ID set: export PROJECT_ID=$(gcloud config get-value project)

---

# 1. Create H100 GPU Node Pool with Autoscaling from Zero
# Status: Ready to deploy
# Command:
#
# gcloud container node-pools create h100-conf \
#   --cluster=vaultmesh-cluster \
#   --region=us-central1 \
#   --machine-type=a3-highgpu-1g \
#   --accelerator type=nvidia-h100-80gb,count=1,gpu-driver-version=latest \
#   --enable-autoscaling \
#   --num-nodes=0 \
#   --min-nodes=0 \
#   --max-nodes=50 \
#   --spot \
#   --enable-image-streaming \
#   --disk-type=pd-ssd \
#   --disk-size=500 \
#   --scopes=cloud-platform \
#   --no-enable-stackdriver-kubernetes

# Notes on configuration:
# - machine-type=a3-highgpu-1g: 1x H100 80GB GPU + 12 CPU cores
# - accelerator: nvidia-h100-80gb (NVIDIA H100 Tensor GPU)
# - gpu-driver-version=latest: Auto-update NVIDIA drivers
# - enable-autoscaling: Scales based on demand
# - num-nodes=0: Starts with zero nodes (cost savings)
# - min-nodes=0: Can scale down to zero when no workloads
# - max-nodes=50: Maximum capacity (tune to your needs)
# - spot: Use GCP Spot instances (preemptible, 70% cheaper)
# - enable-image-streaming: Faster pod startup (O container images streamed on-demand)
# - disk-type=pd-ssd: NVMe-backed persistent disk
# - disk-size=500: 500GB for model weights + temporary data
# - scopes=cloud-platform: Full GCP API access (for attestation)

# Cost breakdown (us-central1):
#   A3-highgpu-1g on-demand:  ~$7.50/hr
#   A3-highgpu-1g spot:       ~$2.25/hr (70% discount)
#   H100 on-demand:           ~$4.00/hr
#   H100 spot:                ~$1.20/hr
#   ---
#   Total on-demand:          ~$11.50/hr
#   Total spot:               ~$3.45/hr

---

# 2. Label and Taint GPU Node Pool
# Status: Ready to deploy
# Command:
#
# gcloud container node-pools update h100-conf \
#   --cluster=vaultmesh-cluster \
#   --region=us-central1 \
#   --node-taints gpu=true:NoSchedule \
#   --node-labels gpu=h100,confidential=true,compute-tier=premium

# Explanation:
# - Taint: NoSchedule prevents regular (non-GPU) pods from landing on GPU nodes
# - Label gpu=h100: Workload selector for GPU-required pods
# - Label confidential=true: Attestation enabled on this pool
# - Label compute-tier=premium: Indicates high-cost pool for scheduling decisions

---

# 3. Enable GPU Autoscaling Metrics (optional but recommended)
# Command:
#
# kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml

# This installs the NVIDIA GPU device plugin which:
# - Makes nvidia.com/gpu available as a schedulable resource
# - Monitors GPU health and availability
# - Enables Kubernetes scheduler to place pods on GPUs

---

# 4. Verify Node Pool Creation
# Command:
#
# gcloud container node-pools list \
#   --cluster=vaultmesh-cluster \
#   --region=us-central1
#
# kubectl get nodes --show-labels

# Expected output:
# - Node pool "h100-conf" listed with machine-type=a3-highgpu-1g
# - Nodes initially = 0 (not created until pods request GPUs)
# - Labels: gpu=h100, confidential=true

---

# 5. Test Autoscaling from Zero
# Command:
#
# # Check initial state
# kubectl get nodes
# # Expected: 3-4 nodes (system pool only)
#
# # Schedule a test pod that requests a GPU
# kubectl run -it --rm test-gpu \
#   --image=tensorflow/tensorflow:latest-gpu \
#   --limits=nvidia.com/gpu=1 \
#   --requests=nvidia.com/gpu=1 \
#   -- python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
#
# # Wait 5-10 minutes for node to provision
# kubectl get nodes -w
# # Expected: +1 new node (a3-highgpu-1g), status=Ready
#
# # After pod completes, watch scale-down (5 min timeout)
# kubectl get nodes -w
# # Expected: Node scales back to 0

---

# 6. Check GPU Availability
# Command:
#
# # After a node joins, verify GPU is available
# kubectl describe node <node-name> | grep -A 5 "Allocated resources"
#
# # Should show: nvidia.com/gpu: 1 (capacity)

---

# 7. Node Pool Outputs
outputs:
  node_pool_name: "h100-conf"
  region: "us-central1"
  machine_type: "a3-highgpu-1g"
  gpu_type: "nvidia-h100-80gb"
  gpu_count: 1
  autoscaling_enabled: true
  min_nodes: 0
  max_nodes: 50
  spot_instances: true
  boot_disk_size_gb: 500
  estimated_cost_per_hour_spot: "$3.45"
  next_step: "Deploy VaultMesh workload (see deployments/vaultmesh-infer.yaml)"

---

# 8. Troubleshooting

troubleshooting:
  "Nodes not provisioning":
    - "Check quota: gcloud compute project-info describe --project=${PROJECT_ID} | grep QUOTA"
    - "Verify region has availability: gcloud compute machine-types list --filter='name:a3-highgpu-1g'"
    - "Check events: kubectl describe node <node-name> | grep -A 10 Events"
  
  "GPU not showing in nvidia.com/gpu":
    - "Verify device plugin is running: kubectl get ds -n kube-system | grep nvidia"
    - "Restart device plugin: kubectl rollout restart ds nvidia-device-plugin -n kube-system"
    - "Check node driver: kubectl run -it --rm nvidia-test --image=nvidia/cuda:11.8.0-runtime-ubuntu22.04 -- nvidia-smi"
  
  "Pods pending even with GPU available":
    - "Check tolerations: kubectl describe pod <pod> | grep Tolerations"
    - "Verify nodeSelector: kubectl describe pod <pod> | grep Node-Selectors"
    - "Check resource requests: kubectl get pod <pod> -o yaml | grep -A 5 resources"
  
  "High spot instance preemption":
    - "Increase max-nodes to have buffer: gcloud container node-pools update h100-conf --max-nodes=100"
    - "Use on-demand for critical workloads: --spot=false (but 3x cost)"
    - "Implement Pod Disruption Budgets in deployment YAML"

---

# 9. Scaling Examples

scaling_scenarios:
  "Light workload (2 jobs/hr, 15 min each)":
    - "Max nodes needed: 1-2"
    - "Estimated cost: $3-7/hr (spot)"
    - "Total daily: $72-168"
  
  "Medium workload (10 jobs/day, 30 min each)":
    - "Max nodes needed: 3-5"
    - "Estimated cost: $10-17/hr (spot)"
    - "Total daily: $240-400"
  
  "High workload (100+ concurrent)":
    - "Max nodes needed: 30-50"
    - "Estimated cost: $100-170/hr (spot)"
    - "Consider: Multi-region + federation + workload sharing"

---

# 10. Production Hardening Checklist

hardening:
  - "✅ Pod Disruption Budgets (PDB) defined for critical workloads"
  - "✅ Node affinity rules for workload distribution"
  - "✅ Resource quotas per namespace"
  - "✅ NetworkPolicy for pod-to-pod communication"
  - "✅ RBAC for service account permissions"
  - "✅ Monitoring/alerting on node health + GPU utilization"
  - "✅ Backup strategy for persistent data"
  - "✅ Preemption handlers for graceful shutdown"

# See deployments/vaultmesh-infer.yaml for complete workload definition
