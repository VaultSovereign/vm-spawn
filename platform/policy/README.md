# VaultMesh Platform Policy

Security and operational policies enforced on the GKE cluster.

## 📋 Contents

### Gatekeeper Constraints ([gatekeeper-constraints.yaml](gatekeeper-constraints.yaml))

OPA Gatekeeper admission control policies:

1. **SHA/Digest Requirement**
   - Constraint: `K8sRequireShaOrTag`
   - Scope: `vaultmesh` namespace
   - Enforces: Only SHA256 digests or commit SHA tags allowed
   - Prevents: Mutable `:latest` or semantic version tags

2. **Resource Requests/Limits**
   - Constraint: `K8sContainerResources`
   - Scope: `vaultmesh` namespace
   - Enforces: All containers must specify CPU/memory requests and limits
   - Ranges: CPU 100m-4, Memory 128Mi-8Gi

### Network Policies ([network-policies.yaml](network-policies.yaml))

Zero-trust networking rules:

1. **Application-level allow rules**:
   - `allow-aurora-to-psi`: Aurora Router → PSI Field (port 8000)
   - `allow-aurora-to-intelligence`: Aurora Router → Intelligence (port 8001)
   - `allow-scheduler-egress`: Scheduler → all services

2. **Infrastructure allow rules**:
   - `allow-gke-health-checks`: GKE/GCP health checks and load balancers
   - `allow-dns-and-external-https`: DNS (UDP/53) and HTTPS (TCP/443) egress

3. **Default deny** (apply last):
   - `default-deny-all`: Denies all ingress and egress not explicitly allowed

## 🚀 Deployment

### Prerequisites

Install Gatekeeper (once per cluster):

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Wait for readiness
kubectl -n gatekeeper-system wait --for=condition=ready pod -l control-plane=controller-manager --timeout=120s
```

### Apply Policies

```bash
cd platform/policy

# 1. Apply Gatekeeper constraints
kubectl apply -f gatekeeper-constraints.yaml

# 2. Test network policies (without default-deny first)
# Comment out the default-deny-all policy in network-policies.yaml
kubectl apply -f network-policies.yaml

# 3. Validate service communication still works
curl -fsS https://aurora.vaultmesh.cloud/healthz
curl -fsS https://psi-field.vaultmesh.cloud/healthz

# 4. Once validated, apply default-deny
# Uncomment default-deny-all in network-policies.yaml
kubectl apply -f network-policies.yaml
```

## 🔍 Verification

### Check Gatekeeper Constraints

```bash
# List all constraints
kubectl get constraints

# View specific constraint
kubectl describe k8srequireshaortag require-sha-tags-vaultmesh

# Check violations (should be empty if all compliant)
kubectl get k8srequireshaortag require-sha-tags-vaultmesh -o jsonpath='{.status.violations}'
```

### Check Network Policies

```bash
# List all policies
kubectl get networkpolicies -n vaultmesh

# Describe specific policy
kubectl describe networkpolicy allow-aurora-to-psi -n vaultmesh

# Test connectivity (from inside a pod)
kubectl exec -n vaultmesh deployment/aurora-router -- curl -fsS http://psi-field:8000/healthz
```

## 🛡️ Security Benefits

1. **Immutable Images**: Prevents accidental or malicious tag mutations
2. **Resource Governance**: Prevents resource exhaustion, enables cost predictability
3. **Network Segmentation**: Limits blast radius of compromised workloads
4. **Defense in Depth**: Multiple enforcement layers (admission + runtime)

## 📊 Operational Impact

- **Build-time enforcement**: Gatekeeper blocks non-compliant deployments before creation
- **Runtime enforcement**: NetworkPolicies actively filter traffic
- **Zero performance overhead**: Gatekeeper is admission-only, NetworkPolicies use kernel filtering
- **Auditable**: All policy violations logged to GKE audit logs

## 🔧 Customization

### Add New Service Allow Rule

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-<source>-to-<dest>
  namespace: vaultmesh
spec:
  podSelector:
    matchLabels:
      app: <destination-service>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: <source-service>
      ports:
        - protocol: TCP
          port: <port-number>
```

### Adjust Resource Limits

Edit `gatekeeper-constraints.yaml` → `K8sContainerResources` parameters:

```yaml
parameters:
  cpu:
    min: "200m"  # Increase minimum
    max: "8"     # Increase maximum
  memory:
    min: "256Mi"
    max: "16Gi"
```

## 🆘 Troubleshooting

**Deployment blocked by Gatekeeper**:
```bash
# Error: "Container X uses unpinned image: Y"
# Fix: Ensure image uses SHA256 digest or commit SHA tag
# Your CI/CD already does this automatically
```

**Service can't reach another service**:
```bash
# 1. Check if NetworkPolicy allows the connection
kubectl describe networkpolicy -n vaultmesh

# 2. Temporarily remove default-deny to test
kubectl delete networkpolicy default-deny-all -n vaultmesh

# 3. Add specific allow rule, then re-apply default-deny
```

**GKE health checks failing**:
```bash
# Ensure allow-gke-health-checks policy is applied
kubectl get networkpolicy allow-gke-health-checks -n vaultmesh

# Check IP ranges match your GKE config
kubectl describe networkpolicy allow-gke-health-checks -n vaultmesh
```

## 📚 References

- [OPA Gatekeeper Docs](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [GKE Network Policy](https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy)
- [GCP Health Check IP Ranges](https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges)
