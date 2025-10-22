# 🜂 Aurora GA v1.0.0 — Verification & Operations

**Status:** ✅ PRODUCTION SEALED  
**Checksum:** `acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8`  
**GPG Key:** `6E4082C6A410F340`  
**Tag:** `v1.0.0-aurora`

---

## Quick Verification (30 seconds)

```bash
# One-command verification
./scripts/verify-aurora-ga.sh

# Expected: ✅ All checks passed
```

**Manual verification:**
```bash
# 1. Verify checksum
shasum -a 256 dist/aurora-20251022.tar.gz
# acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8

# 2. Verify signature
gpg --verify dist/aurora-20251022.tar.gz.asc dist/aurora-20251022.tar.gz
# Good signature from "Sovereign <sovereign@vaultmesh.io>"

# 3. Verify tag
git tag -v v1.0.0-aurora
# Good signature (6E4082C6A410F340)
```

---

## What Is Aurora?

**Aurora** is a treaty-based compute orchestration system that routes GPU workloads across decentralized providers (Akash, io.net, Render, Flux, Aethir, Vast.ai, Salad) with:

- **Cryptographic provenance** (Merkle + RFC3161 + IPFS)
- **Policy enforcement** (vault-law WASM policies)
- **Multi-provider routing** (treaty-aware scheduling)
- **Sovereign verification** (reproducible builds + signed artifacts)

---

## Quick Start

### 1. Run Smoke Test
```bash
make smoke-e2e
# ✅ Validates: keys, bridge, metrics, simulator, provenance
```

### 2. Run Simulator
```bash
make sim-run
# Outputs: sim/multi-provider-routing-simulator/out/*.csv
```

### 3. Monitor SLOs
```bash
# Generate 72h canary report
python3 scripts/canary-slo-reporter.py

# View signed report
cat canary_slo_report.json
gpg --verify canary_slo_report.json.asc
```

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| **[VERIFICATION.md](dist/VERIFICATION.md)** | External verifier guide (6 steps) |
| **[DEPLOYMENT_PLAN.md](AURORA_GA_DEPLOYMENT_PLAN.md)** | 0-48h → 7d → 72h → 30d rollout |
| **[READINESS.md](AURORA_RC1_READINESS.md)** | Production checklist (9.5/10) |
| **[RUNBOOK.md](docs/AURORA_RUNBOOK.md)** | Operations guide + incident response |
| **[COMPLIANCE.md](AURORA_GA_COMPLIANCE_ANNEX.md)** | Audit trail + evidence pack |

---

## Key Artifacts

### Verification
- `scripts/verify-aurora-ga.sh` — Complete verification suite
- `dist/VERIFICATION.md` — External verifier guide
- `dist/aurora-20251022.tar.gz` — Release bundle
- `dist/aurora-20251022.tar.gz.asc` — GPG signature

### Monitoring
- `ops/grafana/grafana-kpi-panels-patch.json` — SLO dashboard
- `scripts/canary-slo-reporter.py` — Governance reporter
- `ops/grafana/aurora-alert-rules.yaml` — Alert definitions

### Operations
- `scripts/smoke-e2e.sh` — End-to-end validation
- `scripts/nonce-cache-helper.py` — Replay protection
- `scripts/ack-verify.py` — Provider signature validation
- `scripts/policy-host-adapter.py` — WASM policy executor

---

## SLO Targets

| Metric | Target | Monitoring |
|--------|--------|------------|
| Fill Rate (p95) | ≥ 0.80 | `treaty_fill_rate_bucket` |
| RTT (p95) | ≤ 350ms | `treaty_rtt_ms_bucket` |
| Provenance Coverage | ≥ 0.95 | `treaty_provenance_coverage` |
| Policy Latency (p99) | ≤ 25ms | `policy_decision_ms_bucket` |

**Prometheus:** `http://localhost:9109/metrics`  
**Grafana:** Import `ops/grafana/grafana-kpi-panels-patch.json`

---

## Deployment Phases

### Phase 0: Lock Perimeter (0-48h)
```bash
# Publish artifacts
git push origin main

# Start staging soak
kubectl apply -k ops/k8s/overlays/staging
make smoke-e2e
```

### Phase 1: 7-Day Soak
```bash
# Daily smoke + ledger backup
make smoke-e2e
sqlite3 ops/data/remembrancer.db ".backup ops/backups/ledger-$(date +%Y%m%d).db"
```

### Phase 2: Canary (72h @ 10%)
```bash
# Deploy canary
kubectl apply -f ops/k8s/canary/traffic-split.yaml

# Monitor + report
python3 scripts/canary-slo-reporter.py --output reports/canary-72h.json
```

### Phase 3: Full Rollout
```bash
# Gradual scale: 25% → 50% → 100%
kubectl patch deployment aurora-bridge -p '{"spec":{"replicas":3}}'
```

---

## Emergency Procedures

### Immediate Rollback
```bash
kubectl rollout undo deployment/aurora-bridge -n aurora-production
kubectl scale deployment/aurora-bridge-backup --replicas=3
```

### Data Recovery
```bash
aws s3 cp s3://vaultmesh-backups/ledger-latest.db.gz .
gunzip ledger-latest.db.gz
sqlite3 ops/data/remembrancer.db ".restore ledger-latest.db"
./ops/bin/remembrancer verify-audit
```

---

## Verification Checklist

- [ ] Checksum matches: `acec72...569a8`
- [ ] GPG signature valid (key: `6E4082C6A410F340`)
- [ ] Git tag signed: `v1.0.0-aurora`
- [ ] Merkle audit passes: `./ops/bin/remembrancer verify-audit`
- [ ] Smoke test passes: `make smoke-e2e`
- [ ] SLO dashboard imported
- [ ] Alert rules configured
- [ ] Runbook reviewed

---

## Support

- **Verification issues:** See [VERIFICATION.md](dist/VERIFICATION.md)
- **Operations issues:** See [RUNBOOK.md](docs/AURORA_RUNBOOK.md)
- **Deployment questions:** See [DEPLOYMENT_PLAN.md](AURORA_GA_DEPLOYMENT_PLAN.md)
- **GitHub Issues:** https://github.com/VaultSovereign/vm-spawn/issues

---

## Covenant State

```
Law = protocol
Compute = sovereign energy
Federation = operational
Truth = cryptographically provable
```

**Aurora GA is sealed. The covenant is enforced. Begin verification.**

🜂
