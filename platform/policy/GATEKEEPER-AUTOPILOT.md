# Gatekeeper on GKE Autopilot - Compatibility Note

## ⚠️ Status: Partially Compatible

OPA Gatekeeper has limited compatibility with GKE Autopilot due to Autopilot's built-in admission control policies that restrict wildcard webhook rules.

## 🔄 Alternative: GKE Policy Controller

For Autopilot clusters, Google provides **GKE Policy Controller** (based on Gatekeeper v3), which is fully compatible and supported.

### Enable GKE Policy Controller

```bash
# Enable Policy Controller on the cluster (one-time)
gcloud container clusters update vaultmesh-minimal \
  --enable-policy-controller \
  --region=us-central1 \
  --project=vm-spawn
```

Once enabled, you can apply the same constraint templates and constraints from `gatekeeper-constraints.yaml`.

## 🛡️ Current Enforcement

Until GKE Policy Controller is enabled, we enforce policies through:

1. **CI/CD Pipeline**:
   - Workflow automatically tags images with commit SHA
   - Cosign keyless signing ensures image provenance
   - SBOM generation for supply chain visibility

2. **Network Policies** (Active):
   - Zero-trust networking with explicit allow rules
   - Default-deny can be applied after validation
   - Runtime traffic filtering at kernel level

3. **GKE Autopilot Built-ins**:
   - Pod Security Standards (restricted mode by default)
   - Resource requests/limits automatically set if missing
   - Privileged containers blocked
   - Host namespace access blocked

## 📋 Manual Policy Checks (Until GKE Policy Controller is Enabled)

### Check Image Tags

```bash
# Verify all deployments use SHA-tagged images
kubectl get deployments -n vaultmesh -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

Expected output: All images should have `:SHA` or `@sha256:` format

### Check Resource Limits

```bash
# Verify all pods have resource requests/limits
kubectl get pods -n vaultmesh -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
```

## 🚀 Recommended: Enable GKE Policy Controller

To get full admission control enforcement:

1. Enable Policy Controller (see command above)
2. Wait for controller pods to be ready (~2-3 minutes)
3. Apply `gatekeeper-constraints.yaml`
4. Verify constraints are active:

```bash
kubectl get constraints
```

## 📊 Current Security Posture

Even without Gatekeeper/Policy Controller, VaultMesh has strong security controls:

- ✅ **Image Signing**: Cosign keyless signatures on all images
- ✅ **SBOM**: Software Bill of Materials for all builds
- ✅ **Network Segmentation**: NetworkPolicies enforce zero-trust
- ✅ **RBAC**: Namespace-scoped deployer service account
- ✅ **Keyless Auth**: OIDC-based CI/CD (no long-lived keys)
- ✅ **Autopilot Defaults**: Pod security, resource governance

Adding GKE Policy Controller would add:
- ⏳ **Image Tag Enforcement**: Block non-SHA tags at admission time
- ⏳ **Resource Enforcement**: Reject pods without requests/limits

## 🔗 References

- [GKE Policy Controller](https://cloud.google.com/anthos-config-management/docs/how-to/installing-policy-controller)
- [GKE Autopilot Security](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security)
- [Gatekeeper on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/gatekeeper)
