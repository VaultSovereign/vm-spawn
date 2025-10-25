# VaultMesh Security Hardening - Deployment Evidence

**Captured**: 2025-10-25T12:28:07Z
**Cluster**: vaultmesh-minimal (GKE Autopilot, us-central1)
**Namespace**: vaultmesh

This document provides verifiable evidence that security hardening measures are actually deployed and active (not just documented).

---

## 1. Workload Identity Federation - Main Branch Restriction

**Claim**: Only `main` branch can deploy to production

**Evidence**:
```yaml
# gcloud iam service-accounts get-iam-policy vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com
bindings:
- members:
  - principalSet://iam.googleapis.com/projects/572946311311/locations/global/workloadIdentityPools/gh-oidc-pool/attribute.repository/VaultSovereign/vm-spawn,attribute.ref/refs/heads/main
  role: roles/iam.workloadIdentityUser
etag: BwZB-oky-VE=
version: 1
```

**Interpretation**:
- Only principal that matches `attribute.repository=VaultSovereign/vm-spawn` **AND** `attribute.ref=refs/heads/main` can assume the deployer service account
- Feature branches (e.g., `refs/heads/feature-xyz`) will be denied
- Pull requests from forks will be denied
- Manual runs from other branches will be denied

**Verification Command**:
```bash
gcloud iam service-accounts get-iam-policy \
  vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com \
  --project=vm-spawn \
  --format=yaml
```

---

## 2. Network Policies - Zero Trust Enforcement

**Claim**: Default-deny network policy active with explicit allow rules

**Evidence**:
```
# kubectl get networkpolicies -n vaultmesh
NAME                           POD-SELECTOR              AGE
allow-aurora-to-intelligence   app=aurora-intelligence   15m
allow-aurora-to-psi            app=psi-field             15m
allow-dns-and-external-https   <none>                    15m
allow-gke-health-checks        <none>                    15m
allow-scheduler-egress         app=scheduler             15m
default-deny-all               <none>                    15m
```

**Default Deny Policy Details**:
```yaml
# kubectl get networkpolicy default-deny-all -n vaultmesh -o yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: vaultmesh
spec:
  podSelector: {}        # Applies to all pods
  policyTypes:
    - Ingress            # Blocks all ingress traffic
    - Egress             # Blocks all egress traffic
```

**Pod Health After Enforcement**:
```
# kubectl get pods -n vaultmesh
NAME                                   READY   STATUS    RESTARTS   AGE
aurora-intelligence-5f8c45cdb6-lxcqw   1/1     Running   0          15m
aurora-intelligence-5f8c45cdb6-t7tfg   1/1     Running   0          15m
aurora-router-84b5dcc78c-q86td         1/1     Running   0          15m
aurora-router-84b5dcc78c-qsq85         1/1     Running   0          16m
psi-field-7b9c5d4bd8-twcjf             1/1     Running   0          15m
scheduler-689b48dcc7-5x67c             1/1     Running   0          15m
vaultmesh-analytics-7c796bf9f-4kvq8    1/1     Running   0          16m
vaultmesh-analytics-7c796bf9f-tx8m9    1/1     Running   0          15m
```

**Interpretation**:
- All 6 NetworkPolicies successfully applied
- Default-deny active (blocks all traffic not explicitly allowed)
- All pods healthy (allow rules permit required communication)
- Health checks working (GKE health check policy allows GCP probes)

**Verification Command**:
```bash
kubectl get networkpolicies -n vaultmesh
kubectl describe networkpolicy default-deny-all -n vaultmesh
```

---

## 3. Current Deployment State

**Claim**: All services running with SHA-tagged images (except pre-hardening deployments)

**Evidence**:
```
# kubectl get deployments -n vaultmesh -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'

aurora-intelligence    us-central1-docker.pkg.dev/vm-spawn/vaultmesh/aurora-intelligence:0.1.2
aurora-router          us-central1-docker.pkg.dev/vm-spawn/vaultmesh/aurora-router:0.2.0
psi-field              us-central1-docker.pkg.dev/vm-spawn/vaultmesh/psi-field:d1ad03f888c713a064d189e2e50bf414f5b15925
scheduler              us-central1-docker.pkg.dev/vm-spawn/vaultmesh/scheduler:1.1.0
vaultmesh-analytics    us-central1-docker.pkg.dev/vm-spawn/vaultmesh/analytics:1.0.0
```

**Interpretation**:
- **psi-field**: ✅ Using SHA tag `d1ad03f...` (deployed via hardened CI/CD)
- **Others**: ⏳ Using semantic versions (pre-hardening deployments)
- **Next deployment** from main will use SHA tags + Cosign signatures + SBOM

**Note**: Semantic versions will transition to SHA tags on next deployment via CI/CD.

---

## 4. CI/CD Workflow Enhancements

**Claim**: Workflow includes Cosign signing, SBOM generation, Slack notifications

**Evidence**: [.github/workflows/ci-cd-autopilot.yml](../../.github/workflows/ci-cd-autopilot.yml)

**Key additions**:

### Cosign Installation (Line 140-146):
```yaml
- name: Install Cosign (keyless signing)
  run: |
    COSIGN_VERSION=2.4.1
    curl -sSL -o cosign.tgz "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64.tar.gz"
    tar -xzf cosign.tgz
    sudo mv cosign /usr/local/bin/cosign
    cosign version
```

### Image Signing (Line 148-154):
```yaml
- name: Sign image with Cosign (OIDC)
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: |
    IMAGE="${{ steps.build.outputs.image }}"
    echo "🔏 Signing $IMAGE"
    cosign sign --yes "$IMAGE"
```

### SBOM Generation (Line 156-174):
```yaml
- name: Install Syft (SBOM generation)
  run: |
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    syft version

- name: Generate SBOM (SPDX JSON)
  run: |
    mkdir -p sbom
    IMAGE="${{ steps.build.outputs.image }}"
    SERVICE="${{ matrix.service }}"
    echo "🧾 Generating SBOM for $IMAGE"
    syft "$IMAGE" -o spdx-json > "sbom/$SERVICE-${{ github.sha }}.spdx.json"

- name: Upload SBOM artifact
  uses: actions/upload-artifact@v4
  with:
    name: sbom-${{ matrix.service }}-${{ github.sha }}
    path: sbom/
    retention-days: 30
```

### Slack Notifications (Line 278-298):
```yaml
- name: Notify on failure (Slack)
  if: failure() || needs.deploy.result == 'failure'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    [ -z "$SLACK_WEBHOOK_URL" ] && { echo "No Slack webhook configured"; exit 0; }
    payload=$(cat <<EOF
    {
      "text": "❌ VaultMesh deployment failed",
      "attachments": [{
        "color": "danger",
        "fields": [
          {"title": "Commit", "value": "${{ github.sha }}", "short": true},
          {"title": "Run ID", "value": "${{ github.run_id }}", "short": true},
          {"title": "Services", "value": "${{ needs.detect-changes.outputs.services }}", "short": false}
        ]
      }]
    }
    EOF
    )
    curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
```

**Status**:
- ✅ Cosign: Integrated (keyless OIDC)
- ✅ SBOM: Integrated (SPDX JSON, 30-day retention)
- ⏳ Slack: Ready (requires `SLACK_WEBHOOK_URL` secret)

**Verification**: Trigger deployment and check GitHub Actions logs for signing/SBOM steps

---

## 5. Gatekeeper / Policy Controller Status

**Claim**: Gatekeeper templates created, not deployed (Autopilot compatibility issues)

**Evidence**:
- ❌ Gatekeeper: **Not installed** (attempted, removed due to Autopilot webhook conflicts)
- ✅ Templates: Created in [platform/policy/gatekeeper-constraints.yaml](gatekeeper-constraints.yaml)
- ℹ️ Alternative: GKE Policy Controller (Autopilot-compatible, not yet enabled)

**Current State**:
```bash
# kubectl get namespace gatekeeper-system
Error from server (NotFound): namespaces "gatekeeper-system" not found
```

**Reason**: GKE Autopilot has built-in admission webhooks that conflict with standard Gatekeeper.

**Path Forward**: Enable GKE Policy Controller (managed service):
```bash
gcloud container clusters update vaultmesh-minimal \
  --enable-policy-controller \
  --region=us-central1 \
  --project=vm-spawn
```

**Documentation**: [GATEKEEPER-AUTOPILOT.md](GATEKEEPER-AUTOPILOT.md)

---

## 6. Security Posture Summary

| Control | Documented | Deployed | Verified |
|---------|------------|----------|----------|
| **WIF Main-Branch Lock** | ✅ | ✅ | ✅ (IAM policy shown above) |
| **NetworkPolicies** | ✅ | ✅ | ✅ (6 policies active) |
| **Default Deny** | ✅ | ✅ | ✅ (policy spec shown above) |
| **Cosign Signing** | ✅ | ✅ | ⏳ (next deployment) |
| **SBOM Generation** | ✅ | ✅ | ⏳ (next deployment) |
| **Slack Alerts** | ✅ | ⏳ | ⏳ (needs secret) |
| **Gatekeeper** | ✅ | ❌ | N/A (Autopilot incompatible) |
| **Policy Controller** | ✅ | ⏳ | ⏳ (needs enabling) |

**Legend**:
- ✅ Complete
- ⏳ Ready but not activated
- ❌ Not deployed

---

## 7. Next Deployment Will Include

When the next service is deployed via CI/CD:

1. **Image Build**: Tagged with commit SHA
2. **Cosign Signature**: Keyless OIDC signature published to Rekor
3. **SBOM**: SPDX JSON uploaded to GitHub Actions artifacts
4. **Deployment**: Rolling update with health checks
5. **Network Enforcement**: Traffic filtered by active NetworkPolicies

**To trigger**: Make any change to `services/*/src/`, `services/*/Dockerfile`, or `services/*/k8s/` and push to main.

---

## 8. Verification Checklist

Run these commands to verify active state:

```bash
# 1. WIF restriction
gcloud iam service-accounts get-iam-policy \
  vaultmesh-deployer@vm-spawn.iam.gserviceaccount.com \
  --project=vm-spawn | grep "attribute.ref"
# ✅ Should show: refs/heads/main

# 2. NetworkPolicies
kubectl get networkpolicies -n vaultmesh
# ✅ Should show: 6 policies

# 3. Default deny active
kubectl describe networkpolicy default-deny-all -n vaultmesh | grep "Policy Types"
# ✅ Should show: Ingress, Egress

# 4. Pods healthy
kubectl get pods -n vaultmesh | grep -v Running
# ✅ Should show: (empty, all Running)

# 5. Latest workflow
gh run list --repo VaultSovereign/vm-spawn --workflow "VaultMesh Deploy" --limit 1
# ✅ Should show: ci-cd-autopilot.yml run

# 6. Policy files committed
ls platform/policy/*.yaml
# ✅ Should show: gatekeeper-constraints.yaml, network-policies.yaml
```

---

## 9. Audit Trail

All changes tracked in git history:

```bash
# View security hardening commits
git log --oneline --grep="hardening\|policy\|security" --all

# Recent security commits:
# 141a9df docs: add comprehensive security hardening summary
# 415a8a5 feat(platform): add policy framework (NetworkPolicies, Gatekeeper templates)
# f601cdf feat(ci): add supply chain hardening (Cosign, SBOM, Slack alerts)
# 6600411 fix(ci): install gke-gcloud-auth-plugin for kubectl GKE access
# 8dd9815 fix(ci): correct JSON array generation in matrix setup
```

---

## 10. Future Evidence Updates

As additional hardening is deployed, this document will be updated with:

- [ ] GKE Policy Controller installation evidence
- [ ] First Cosign-signed deployment (Rekor log URL)
- [ ] First SBOM artifact (GitHub Actions artifact link)
- [ ] Slack notification test (redacted webhook URL + screenshot)
- [ ] Binary Authorization policy (if enabled)
- [ ] Vulnerability scanning results (if enabled)

**Last Updated**: 2025-10-25T12:28:07Z
