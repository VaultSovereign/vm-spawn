# VaultMesh GCP Minimal Deployment — Scale-to-Zero

**Perfect for:** Solo devs, low traffic, sporadic usage
**Cost:** ~$35-50/month idle, scales up only when needed
**Time:** 10-15 minutes to deploy

---

## Philosophy

**Traditional deployment:**
- Services always running (24/7)
- Fixed number of nodes
- Paying for idle resources
- Cost: $350-450/month

**Minimal on-demand deployment:**
- Services scaled to ZERO when idle
- Nodes scale down to minimum
- Wake automatically on queue messages
- GPU nodes only created when needed
- Cost: $35-50/month idle, pay-per-use when active

---

## What You Get

### Services (Scale-to-Zero)
- **Psi-Field:** 0 replicas → scales 0-10 on Pub/Sub messages
- **Scheduler:** 0 replicas → scales 0-5 on Pub/Sub messages
- **GPU Jobs:** No nodes → spins up H100/A100 only when job submitted

### Infrastructure (Minimal)
- **Cluster:** 1x e2-small node (baseline for KEDA/system pods)
- **GPU Pool:** 0 nodes → autoscales 0-10 on demand
- **KEDA:** Queue-driven autoscaling
- **Workload Identity:** Secure Pub/Sub access
- **No LoadBalancers:** Internal services only (saves $18/LB/month)

### Cost Breakdown

| State | Resources | Monthly Cost |
|-------|-----------|--------------|
| **Idle** | 1x e2-small + control plane | ~$35-50 |
| **Light usage** | +1-2 pods (5% time) | ~$50-80 |
| **Medium usage** | +5 pods (20% time) | ~$100-150 |
| **Heavy usage** | +10 pods (50% time) | ~$200-300 |
| **GPU job (1hr)** | +1x A100 | ~$3/hour |

---

## One-Command Deployment

```bash
# 1. Set your GCP project ID
export PROJECT_ID="your-project-id-here"

# 2. Optional: Use GKE Autopilot (fully managed, pay-per-pod)
export USE_AUTOPILOT=true  # or false for standard cluster

# 3. Deploy
./deploy-gcp-minimal.sh
```

**That's it!** Services start at 0 replicas and wake automatically when work arrives.

---

## How It Works

### 1. Queue-Driven Scaling (KEDA)

When you publish a message to Pub/Sub:

```bash
# Publish job to Psi-Field queue
gcloud pubsub topics publish vaultmesh-psi-jobs \
  --message='{"task": "predict", "data": {...}}'

# KEDA detects message → scales deployment from 0 to 1
# Cluster autoscaler creates node if needed
# Pod processes job, pulls from queue
# After 5 minutes idle → scales back to 0
```

**Flow:**
```
Message → Pub/Sub → KEDA → Pod (0→1→N) → Node (if needed) → Process → Scale down
```

### 2. GPU On-Demand

GPU nodes start at 0 and only spin up when GPU jobs are submitted:

```bash
# Submit GPU job
gcloud pubsub topics publish vaultmesh-gpu-jobs \
  --message='{"model": "llama-2-70b", "prompt": "Hello"}'

# KEDA creates Kubernetes Job
# Job requests nvidia.com/gpu: 1
# Cluster autoscaler creates GPU node (A100/H100)
# Job runs, completes, deletes
# After 5-10 minutes → GPU node deleted
```

**Cost:** Only pay for GPU time actually used (~$3/hour for A100).

---

## Configuration

### Add GPU Node Pool

```bash
# A100 GPU pool (min-nodes=0)
gcloud container node-pools create gpu-a100 \
  --cluster=vaultmesh-minimal \
  --region=us-central1 \
  --machine-type=a2-highgpu-1g \
  --accelerator type=nvidia-tesla-a100,count=1,gpu-driver-version=latest \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10 \
  --node-taints=gpu=true:NoSchedule \
  --node-labels=gpu=a100

# Create Pub/Sub for GPU jobs
gcloud pubsub topics create vaultmesh-gpu-jobs
gcloud pubsub subscriptions create vaultmesh-gpu-jobs-sub \
  --topic=vaultmesh-gpu-jobs \
  --ack-deadline=600

# Deploy GPU job scaler
kubectl apply -f k8s/keda/gpu-job-scaler.yaml
```

### Adjust Scaling Thresholds

Edit KEDA ScaledObjects:

```bash
# Scale faster (more aggressive)
kubectl edit scaledobject psi-field-scaler -n vaultmesh

# Change:
#   subscriptionSize: "5"  → "2"  # 1 pod per 2 messages
#   cooldownPeriod: 300    → 180  # Scale down after 3 minutes
```

### Change Node Size

```bash
# Use larger nodes for more headroom
gcloud container clusters update vaultmesh-minimal \
  --region=us-central1 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=8

# Or resize existing pool
gcloud container node-pools update default-pool \
  --cluster=vaultmesh-minimal \
  --region=us-central1 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10
```

---

## Monitoring

### Check Scaling Status

```bash
# View current state
kubectl get pods -n vaultmesh
kubectl get scaledobjects -n vaultmesh
kubectl get hpa -n vaultmesh

# Watch live scaling
kubectl get pods -n vaultmesh -w

# Check KEDA metrics
kubectl describe scaledobject psi-field-scaler -n vaultmesh
```

### View Queue Depth

```bash
# Check pending messages
gcloud pubsub subscriptions describe vaultmesh-psi-jobs-sub \
  --format="value(messageRetentionDuration, numUndeliveredMessages)"
```

### Test Scaling

```bash
# Publish 10 test messages
for i in {1..10}; do
  gcloud pubsub topics publish vaultmesh-psi-jobs \
    --message="{\"test\": $i}"
done

# Watch pods scale up
kubectl get pods -n vaultmesh -w
# Should see: 0 → 2 → 3... (depending on queue depth)

# After 5 minutes idle
# Should see: 3 → 2 → 1 → 0
```

---

## Cost Optimization Tips

### 1. Use Preemptible Nodes (Dev/Test)

```bash
gcloud container node-pools create preemptible-pool \
  --cluster=vaultmesh-minimal \
  --region=us-central1 \
  --machine-type=e2-medium \
  --preemptible \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=5

# Cost: ~60% cheaper than regular nodes
```

### 2. Use Spot VMs (Production)

Similar to preemptible but with longer lifetime:

```bash
gcloud container node-pools create spot-pool \
  --cluster=vaultmesh-minimal \
  --region=us-central1 \
  --machine-type=e2-medium \
  --spot \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=5
```

### 3. Aggressive Cooldown

Scale down faster (but may cause cold starts):

```yaml
# In KEDA ScaledObject
cooldownPeriod: 60  # Scale to zero after 1 minute idle
```

### 4. Batching

Process multiple messages per pod:

```yaml
# In KEDA ScaledObject
subscriptionSize: "10"  # 1 pod per 10 messages
```

### 5. GKE Autopilot

Use fully managed cluster (pay only for pods):

```bash
export USE_AUTOPILOT=true
./deploy-gcp-minimal.sh

# Pros: No node management, precise billing
# Cons: Less control, slightly higher per-pod cost
```

---

## Comparison: Standard vs Minimal

| Aspect | Standard Deployment | Minimal On-Demand |
|--------|---------------------|-------------------|
| **Baseline nodes** | 2-6 n2-standard-4 | 1 e2-small |
| **Service replicas** | Always ≥1 | Starts at 0 |
| **GPU nodes** | Fixed pool | Created on-demand |
| **LoadBalancers** | 4 external LBs | 0 (internal only) |
| **Cost (idle)** | $350-450/month | $35-50/month |
| **Cost (active)** | $350-450/month | $100-300/month* |
| **Cold start** | None (always warm) | 30-60s from zero |
| **Best for** | 24/7 production | Sporadic usage |

\* *Active = processing jobs 20-50% of the time*

---

## When to Use Each

### Use **Minimal On-Demand** if:
- ✅ Solo developer / low traffic
- ✅ Usage is sporadic (< 50% time)
- ✅ Cost is primary concern
- ✅ Can tolerate 30-60s cold starts
- ✅ GPU workloads are batch/async

### Use **Standard Deployment** if:
- ✅ Production service with SLAs
- ✅ High traffic (> 50% time)
- ✅ Need instant response (no cold start)
- ✅ Multiple concurrent users
- ✅ Critical path workloads

---

## Troubleshooting

### Pods Not Scaling Up

```bash
# Check KEDA is running
kubectl get pods -n keda

# Check ScaledObject status
kubectl describe scaledobject psi-field-scaler -n vaultmesh

# Check Pub/Sub subscription
gcloud pubsub subscriptions describe vaultmesh-psi-jobs-sub

# Check Workload Identity
kubectl get sa vaultmesh-worker -n vaultmesh -o yaml
```

### Pods Stuck at 0

```bash
# Check for errors in KEDA operator
kubectl logs -n keda deployment/keda-operator

# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:vaultmesh-worker"
```

### GPU Nodes Not Creating

```bash
# Check node pool exists
gcloud container node-pools list \
  --cluster=vaultmesh-minimal \
  --region=us-central1

# Check GPU quota
gcloud compute regions describe us-central1 \
  --format="value(quotas.filter(metric=NVIDIA_A100_GPUS))"

# Check GPU job status
kubectl get jobs -n vaultmesh
kubectl describe job <job-name> -n vaultmesh
```

---

## Advanced: Multi-Queue Setup

Deploy different services for different workload types:

```yaml
---
# Fast lane (low latency, small tasks)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: psi-field-fast
spec:
  scaleTargetRef: { name: psi-field-fast }
  minReplicaCount: 1  # Keep 1 warm for low latency
  maxReplicaCount: 20
  triggers:
  - type: gcp-pubsub
    metadata:
      subscriptionName: vaultmesh-fast-lane
      subscriptionSize: "2"  # Aggressive scaling

---
# Slow lane (high latency ok, large batches)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: psi-field-slow
spec:
  scaleTargetRef: { name: psi-field-slow }
  minReplicaCount: 0  # Scale to zero
  maxReplicaCount: 5
  triggers:
  - type: gcp-pubsub
    metadata:
      subscriptionName: vaultmesh-slow-lane
      subscriptionSize: "20"  # Batch processing
```

---

## Cleanup

```bash
# Delete cluster (removes everything)
gcloud container clusters delete vaultmesh-minimal \
  --region=us-central1 \
  --quiet

# Delete container images
gcloud artifacts repositories delete vaultmesh \
  --location=us-central1 \
  --quiet

# Delete Pub/Sub
gcloud pubsub subscriptions delete vaultmesh-psi-jobs-sub --quiet
gcloud pubsub subscriptions delete vaultmesh-scheduler-jobs-sub --quiet
gcloud pubsub topics delete vaultmesh-psi-jobs --quiet
gcloud pubsub topics delete vaultmesh-scheduler-jobs --quiet
```

---

## Next Steps

1. **Add monitoring** — Deploy lightweight Prometheus (minimal)
2. **Add GPU pool** — For on-demand inference
3. **Set up alerting** — Get notified when scaling issues occur
4. **Optimize images** — Reduce cold start time with smaller images
5. **Pre-warm cache** — Keep models cached in persistent volumes

---

## Support

- **KEDA Docs:** https://keda.sh/docs/
- **GKE Autoscaling:** https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
- **Pub/Sub Pricing:** https://cloud.google.com/pubsub/pricing

---

**Ready to deploy?**

```bash
export PROJECT_ID="your-project-id"
./deploy-gcp-minimal.sh
```

🎯 **Scale-to-zero magic awaits!**
