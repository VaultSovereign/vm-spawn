# VaultMesh GCP Cost Comparison

**Last Updated:** 2025-10-23

---

## TL;DR

| Deployment Type | Idle Cost | Active Cost | Best For |
|----------------|-----------|-------------|----------|
| **Standard (Always-On)** | $350-450/mo | $350-800/mo | Production 24/7 traffic |
| **Minimal (Scale-to-Zero)** | **$35-50/mo** | $100-300/mo | Solo dev, sporadic usage |
| **GPU On-Demand** | **$0/mo** | $3/hour when used | Batch inference jobs |

**Key Insight:** With scale-to-zero, you pay ~$35-50/month for the control plane and 1 tiny node. Everything else (GPUs, workers) costs $0 until you use them.

---

## Detailed Breakdown

### 1. Standard "Always-On" Deployment

**What's running:**
- GKE control plane (regional)
- 2-6 n2-standard-4 nodes (always on)
- Psi-Field: 2 replicas (always running)
- Scheduler: 1 replica (always running)
- Prometheus + Grafana (always running)
- 4 LoadBalancers (external IPs)

**Monthly Costs:**

| Component | Configuration | Cost |
|-----------|--------------|------|
| GKE control plane | Regional cluster | $73 |
| Compute nodes | 2x n2-standard-4 baseline | $200 |
| Autoscaling | +4 nodes when busy | +$400 |
| LoadBalancers | 4 external IPs | $72 |
| Persistent storage | 50GB for Prometheus | $2 |
| Egress traffic | ~500GB/month | $50 |
| **Baseline (idle)** | | **$397/month** |
| **Peak (busy)** | | **$797/month** |

**Pros:**
- ✅ Zero cold start
- ✅ Always responsive
- ✅ Simple to manage
- ✅ Good for production SLAs

**Cons:**
- ❌ Expensive when idle
- ❌ Pay for unused capacity
- ❌ Not cost-effective for low traffic

---

### 2. Minimal "Scale-to-Zero" Deployment

**What's running:**
- GKE control plane (regional)
- 1 e2-small node (KEDA + system pods only)
- **All services: 0 replicas** (nothing running!)
- **GPU pool: 0 nodes** (not created yet)
- No LoadBalancers (ClusterIP only)

**Monthly Costs (Idle State):**

| Component | Configuration | Cost |
|-----------|--------------|------|
| GKE control plane | Regional cluster | $73 |
| Baseline node | 1x e2-small (2 vCPU, 2GB) | $15 |
| KEDA pods | Runs on baseline node | $0 |
| Services (scaled to 0) | No pods running | $0 |
| GPU nodes (min=0) | No nodes | $0 |
| LoadBalancers | None (ClusterIP) | $0 |
| Storage | None initially | $0 |
| **Total (idle)** | | **$88/month** |

Wait, that seems high for "minimal"? Let's optimize further:

**Minimal (Optimized):**

| Component | Configuration | Cost |
|-----------|--------------|------|
| GKE control plane | Single-zone cluster | $73 → **$0** (Autopilot) |
| Baseline node | 1x e2-micro via Autopilot | ~$5-10 |
| KEDA pods | 100m CPU, 128Mi RAM | ~$3 |
| Services (scaled to 0) | Not running | $0 |
| GPU nodes (min=0) | Not created | $0 |
| LoadBalancers | None | $0 |
| **Total (idle, Autopilot)** | | **$8-13/month** 🎉 |

**When Active (20% usage):**

| Component | Cost |
|-----------|------|
| Idle baseline | $8-13 |
| Psi-Field pods (2x, 4h/day) | ~$15 |
| Scheduler pods (1x, 2h/day) | ~$8 |
| Egress traffic (50GB) | ~$5 |
| **Total (light usage)** | **~$36-41/month** |

**When Active (50% usage):**

| Component | Cost |
|-----------|------|
| Idle baseline | $8-13 |
| Psi-Field pods (5x, 12h/day) | ~$75 |
| Scheduler pods (2x, 8h/day) | ~$30 |
| Egress traffic (200GB) | ~$20 |
| **Total (medium usage)** | **~$133-138/month** |

**Pros:**
- ✅ **Near-zero idle cost** ($8-13/month)
- ✅ Pay only for what you use
- ✅ Perfect for solo devs
- ✅ GPU nodes only when needed

**Cons:**
- ⚠️ 30-60s cold start from zero
- ⚠️ Requires queue-based architecture
- ⚠️ Slightly more complex setup

---

### 3. GPU On-Demand (Batch Jobs)

**What's running:**
- Minimal cluster (from above)
- GPU pool with **min-nodes=0** (starts at zero!)
- KEDA ScaledJob watches Pub/Sub queue

**Costs:**

| GPU Type | Hourly Cost | Daily (1 hour) | Monthly (20 hours) |
|----------|-------------|----------------|-------------------|
| NVIDIA T4 | $0.35/hour | $0.35 | $7 |
| NVIDIA A100 (40GB) | $2.48/hour | $2.48 | $50 |
| NVIDIA A100 (80GB) | $3.67/hour | $3.67 | $73 |
| NVIDIA H100 (80GB) | $6.00/hour* | $6.00 | $120 |

\* *H100 pricing estimated; not widely available in all regions*

**Example: LLM inference**
- Job: Generate 1000 tokens with Llama-2-70B
- Time: ~5 minutes on A100
- Cost: ($3.67/hour ÷ 60 min) × 5 min = **$0.31 per job**

**With scale-to-zero:**
- Queue 100 jobs → 1 A100 spins up → processes all → shuts down
- Total time: 500 minutes (8.3 hours)
- Cost: 8.3 × $3.67 = **$30.46**
- Idle cost when no jobs: **$0**

**Pros:**
- ✅ Pay only for GPU time used
- ✅ No idle GPU costs
- ✅ Scales to 10+ GPUs if needed
- ✅ Perfect for batch workloads

**Cons:**
- ⚠️ 2-5 minute startup time (node creation + model loading)
- ⚠️ Not suitable for real-time inference
- ⚠️ Requires async/queue architecture

---

## Real-World Scenarios

### Scenario 1: Solo Dev (1 hour of work per day)

**Standard Deployment:**
- Always-on services: $397/month
- 1 hour of actual use per day
- Waste: ~96% of compute time idle
- **Cost: $397/month**

**Minimal Deployment:**
- Idle baseline: $13/month (Autopilot)
- 1 hour active per day: ~$10/month
- Waste: Near zero
- **Cost: $23/month**

**Savings: $374/month (94% reduction)**

---

### Scenario 2: Weekend Project (2 days/week)

**Standard Deployment:**
- Always-on: $397/month
- Used 8 days/month
- Utilization: ~27%
- **Cost: $397/month**

**Minimal Deployment:**
- Idle baseline: $13/month
- Active 8 days × 8 hours: ~$40/month
- **Cost: $53/month**

**Savings: $344/month (87% reduction)**

---

### Scenario 3: Batch GPU Jobs (5 hours/month)

**Standard with GPU node pool (min=1):**
- Always-on cluster: $397/month
- 1x A100 always running: 720 hours × $3.67 = $2,642/month
- Utilization: 0.7%
- **Cost: $3,039/month**

**Minimal with GPU on-demand (min=0):**
- Idle baseline: $13/month
- GPU only when used: 5 hours × $3.67 = $18/month
- **Cost: $31/month**

**Savings: $3,008/month (99% reduction!)** 🤯

---

### Scenario 4: Growing Startup (50% utilization)

**Standard Deployment:**
- Baseline: $397/month
- Autoscaling: ~50% time at max
- **Cost: ~$600/month**

**Minimal Deployment:**
- Idle baseline: $13/month
- 50% utilization (12h/day): ~$150/month
- **Cost: ~$163/month**

**Savings: $437/month (73% reduction)**

---

## Cost Optimization Tips

### 1. Use GKE Autopilot

**Standard GKE:**
- Pay for nodes (even if pods idle)
- Control plane: $73/month

**GKE Autopilot:**
- Pay only for pods (per vCPU-hour, per GB-hour)
- Control plane: **Free**
- **Savings: $73/month + better pod utilization**

```bash
export USE_AUTOPILOT=true
./deploy-gcp-minimal.sh
```

### 2. Remove LoadBalancers

**4 LoadBalancers:** $72/month

**Use ClusterIP + kubectl port-forward:**
```bash
# When you need access
kubectl port-forward svc/psi-field 8000:8000 &
kubectl port-forward svc/grafana 3000:80 &
```

**Savings: $72/month**

### 3. Use Preemptible/Spot Nodes

**Regular nodes:** $0.09/hour (e2-medium)
**Spot nodes:** $0.03/hour (66% discount)

```bash
gcloud container node-pools create spot-pool \
  --cluster=vaultmesh-minimal \
  --spot \
  --enable-autoscaling --min-nodes=0 --max-nodes=5
```

**Savings: ~66% on compute**

### 4. Aggressive Cooldown

Scale to zero faster:

```yaml
# KEDA ScaledObject
cooldownPeriod: 60  # Scale down after 1 minute idle
```

**Savings: Reduces billable time by scaling faster**

### 5. Regional vs Zonal Cluster

**Regional cluster:** $73/month (high availability)
**Zonal cluster:** $0.10/hour × 720 = $72/month

**Or use Autopilot:** Control plane free

---

## Break-Even Analysis

**When does "always-on" become cheaper than "on-demand"?**

```
Standard cost = $397/month (fixed)
Minimal cost = $13/month (fixed) + $X/hour (variable)

Break-even when:
$397 = $13 + (hours_active × hourly_cost)

For e2-medium pod ($0.05/hour):
$397 = $13 + (H × $0.05)
H = ($397 - $13) / $0.05
H = 7,680 hours/month
```

**Wait, that's 7,680 hours per month?** That's more than 720 hours in a month! Minimal is **always cheaper** for CPU workloads!

**For GPU (A100 @ $3.67/hour):**
```
$397 = $13 + (H × $3.67)
H = 105 hours/month
```

**Conclusion:** Minimal is cheaper if you use GPUs **less than 105 hours/month** (~3.5 hours/day).

---

## Recommendations

### Use **Minimal (Scale-to-Zero)** if:
- ✅ Solo developer
- ✅ Usage < 50% of time
- ✅ Cost-sensitive
- ✅ Batch/async workloads
- ✅ GPU usage < 100 hours/month

### Use **Standard (Always-On)** if:
- ✅ Production SLAs required
- ✅ High traffic (> 80% utilization)
- ✅ Real-time requirements (no cold start)
- ✅ Multiple concurrent users
- ✅ Cost is not primary concern

---

## Summary

| Metric | Standard | Minimal | Savings |
|--------|----------|---------|---------|
| **Idle cost** | $397/mo | $13/mo | **$384/mo (97%)** |
| **Light usage (10%)** | $397/mo | $23/mo | **$374/mo (94%)** |
| **Medium usage (50%)** | $600/mo | $163/mo | **$437/mo (73%)** |
| **GPU batch (5h/mo)** | $3,039/mo | $31/mo | **$3,008/mo (99%)** |

**For solo devs with sporadic usage, minimal deployment saves 90-99% on costs.**

---

**Ready to save money?**

```bash
export PROJECT_ID="your-project-id"
export USE_AUTOPILOT=true  # For maximum savings
./deploy-gcp-minimal.sh
```

💰 **Let's make cloud costs hurt less!**
