# KEDA Autoscaling Configuration for VaultMesh

## Installation

```bash
# Add KEDA Helm repository
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Install KEDA in keda namespace
helm install keda kedacore/keda --namespace keda --create-namespace

# Verify installation
kubectl get pods -n keda
# Expected: keda-operator and keda-metrics-apiserver running
```

## Usage

```bash
# Deploy KEDA ScaledObject
kubectl apply -f keda-scaler.yaml

# Verify ScaledObject is active
kubectl get scaledobject
kubectl describe scaledobject vaultmesh-infer-scaler

# Publish messages to trigger scaling
gcloud pubsub topics publish vaultmesh-jobs --message '{"job_id":"test-001"}'

# Watch pods scale up
kubectl get pods -w -l app=vaultmesh-infer

# Monitor KEDA logs
kubectl logs -n keda -l app=keda-operator -f
```

## Configuration

### Scaling Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `minReplicaCount` | 0 | Minimum pods (0 = scale to zero) |
| `maxReplicaCount` | 50 | Maximum pods (tune to quota) |
| `cooldownPeriod` | 300 | Seconds to wait before scaling down |
| `value` | "10" | Messages per pod (1 pod per 10 msgs) |
| `activationThreshold` | "5" | Min messages before scaling (stay at 0 below this) |

### Tuning Examples

**Light workload (cost optimization):**
```yaml
minReplicaCount: 0
maxReplicaCount: 5
cooldownPeriod: 600
value: "50"              # 1 pod per 50 messages
activationThreshold: "10"
```

**Heavy workload (performance):**
```yaml
minReplicaCount: 0
maxReplicaCount: 50
cooldownPeriod: 60
value: "5"               # 1 pod per 5 messages
activationThreshold: "0" # Scale up immediately
```

## Troubleshooting

### Pods won't scale up

```bash
# Check KEDA can reach Pub/Sub
kubectl logs -n keda -l app=keda-operator | grep -i pubsub

# Verify subscription exists
gcloud pubsub subscriptions describe vaultmesh-jobs

# Check for messages
gcloud pubsub subscriptions pull vaultmesh-jobs --max-messages=5

# Manually publish test message
gcloud pubsub topics publish vaultmesh-jobs --message '{"test":"msg"}'
```

### Pods won't scale down to zero

```bash
# Verify minReplicaCount: 0
kubectl get scaledobject vaultmesh-infer-scaler -o yaml | grep minReplica

# Check if pods have active connections
kubectl exec <pod> -- netstat -an | grep ESTABLISHED

# Increase cooldownPeriod if needed
kubectl patch scaledobject vaultmesh-infer-scaler -p '{"spec":{"cooldownPeriod":600}}'
```

### High preemption rate (Spot instances)

```bash
# Check node preemption events
kubectl get events -A | grep Preempt

# Increase maxReplicaCount to have buffer
kubectl patch scaledobject vaultmesh-infer-scaler -p '{"spec":{"maxReplicaCount":100}}'

# Or use on-demand nodes (3x cost):
gcloud container node-pools update h100-conf \
  --cluster=vaultmesh-cluster \
  --region=us-central1 \
  --spot=false
```

## Files

- `keda-scaler.yaml` - ScaledObject and TriggerAuthentication
- `README.md` - This file
- See `../deployments/vaultmesh-infer.yaml` for the workload
