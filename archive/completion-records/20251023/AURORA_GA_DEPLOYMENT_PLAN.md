# Aurora GA Deployment Plan (v1.0.0)

**Status:** 🜂 READY FOR EXECUTION  
**Checksum:** `acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8`  
**Timeline:** 0-48h (perimeter) → 7d (soak) → 72h (canary) → 30d (optimization)

---

## Phase 0: Lock the Perimeter (0-48 hours)

### ✅ Artifacts Published

- [x] `dist/VERIFICATION.md` — External verifier guide
- [x] `ops/grafana/grafana-kpi-panels-patch.json` — KPI dashboard aligned to SLOs
- [x] `scripts/canary-slo-reporter.py` — 72h governance report generator
- [x] `scripts/verify-aurora-ga.sh` — Complete verification suite

### Tasks

1. **Publish verification guide (external)**
   ```bash
   git add dist/VERIFICATION.md
   git commit -m "docs(aurora): add external verification guide for GA v1.0.0"
   git push origin main
   ```

2. **Start staging soak**
   ```bash
   kubectl apply -k ops/k8s/overlays/staging
   make smoke-e2e
   ```
   
   **Targets:**
   - Fill rate ≥ 0.80 (p95)
   - RTT ≤ 350ms (p95)
   - Provenance ≥ 0.95
   - Policy latency ≤ 25ms

3. **Finalize alert rules & on-call**
   ```bash
   # Load alerts into Grafana
   curl -X POST http://grafana:3000/api/v1/provisioning/alert-rules \
     -H "Content-Type: application/json" \
     -d @ops/grafana/aurora-alert-rules.yaml
   
   # Verify alerts are firing
   curl http://grafana:3000/api/v1/provisioning/alert-rules | jq '.[] | select(.title | contains("Aurora"))'
   ```

4. **Mirror checksum everywhere**
   - ✅ Announcement: `acec72...569a8`
   - ✅ Readiness: `acec72...569a8`
   - ✅ Investor note: `acec72...569a8`
   - ✅ Compliance annex: `acec72...569a8`
   - ✅ Handoff doc: `acec72...569a8`

---

## Phase 1: 7-Day Soak (Prove SLOs)

### Daily Operations

```bash
# Daily smoke test
make smoke-e2e | tee logs/smoke-$(date +%Y%m%d).log

# Daily ledger snapshot (RPO 15m / RTO 1h)
sqlite3 ops/data/remembrancer.db ".backup ops/backups/ledger-$(date +%Y%m%d).db"
gzip ops/backups/ledger-$(date +%Y%m%d).db

# Upload to S3 (optional)
aws s3 cp ops/backups/ledger-$(date +%Y%m%d).db.gz s3://vaultmesh-backups/
```

### Dual-TSA Timestamp Check

```bash
# Verify both TSA endpoints are operational
curl -I https://freetsa.org/tsr
curl -I https://timestamp.digicert.com

# Test timestamp creation
echo "test" > /tmp/test.txt
./ops/bin/remembrancer timestamp /tmp/test.txt
openssl ts -verify -data /tmp/test.txt -in /tmp/test.txt.tsr -CAfile ops/certs/freetsa-ca.pem
```

### Grafana Dashboard Hygiene

```bash
# Import KPI panel patch
curl -X POST http://grafana:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @ops/grafana/grafana-kpi-panels-patch.json

# Verify thresholds match KPI table
# Fill Rate: 0.80 (yellow) → 0.85 (green)
# RTT: 300ms (yellow) → 350ms (red)
# Provenance: 0.90 (yellow) → 0.95 (green)
# Policy: 20ms (yellow) → 25ms (red)
```

### Operator Dry-Runs

```bash
# Practice rollback
kubectl rollout undo deployment/aurora-bridge -n aurora-staging

# Practice failover
kubectl scale deployment/aurora-bridge --replicas=0 -n aurora-staging
kubectl scale deployment/aurora-bridge-backup --replicas=3 -n aurora-staging

# Practice emergency halt
kubectl delete -k ops/k8s/overlays/staging
```

---

## Phase 2: Canary (72h @ 10%)

### Pre-Canary Checklist

- [ ] Staging soak completed (7 days green)
- [ ] All SLOs met for 168 consecutive hours
- [ ] Alert rules validated and paging
- [ ] Rollback procedure tested
- [ ] On-call rotation confirmed

### Deploy Canary

```bash
# Apply 10% traffic split
kubectl apply -f ops/k8s/canary/traffic-split.yaml

# Monitor for 72 hours
watch -n 60 'curl -s http://prometheus:9090/api/v1/query?query=treaty_fill_rate | jq'
```

### Canary Monitoring

```bash
# Hour 24: First checkpoint
python3 scripts/canary-slo-reporter.py --output reports/canary-24h.json

# Hour 48: Second checkpoint
python3 scripts/canary-slo-reporter.py --output reports/canary-48h.json

# Hour 72: Final report
python3 scripts/canary-slo-reporter.py --output reports/canary-72h.json
gpg --verify reports/canary-72h.json.asc reports/canary-72h.json
```

### Rollback Criteria

Rollback immediately if:
- Fill rate < 0.75 for 15 consecutive minutes
- RTT > 400ms (p95) for 15 consecutive minutes
- Provenance coverage < 0.90 for 5 minutes
- Policy latency > 50ms (p99) for 5 minutes
- Any SEV1 alert fires

```bash
# Emergency rollback
kubectl rollout undo deployment/aurora-bridge -n aurora-production
kubectl scale deployment/aurora-bridge-v0 --replicas=3 -n aurora-production
```

### Canary Success Criteria

- [ ] Fill rate ≥ 0.80 (p95) for 72h
- [ ] RTT ≤ 350ms (p95) for 72h
- [ ] Provenance ≥ 0.95 for 72h
- [ ] Policy latency ≤ 25ms (p99) for 72h
- [ ] Zero SEV1/SEV2 incidents
- [ ] Signed SLO report generated

---

## Phase 3: Full Rollout (Post-Canary)

### Gradual Rollout

```bash
# 25% traffic (hour 0)
kubectl patch deployment aurora-bridge -p '{"spec":{"replicas":1}}'

# 50% traffic (hour 6)
kubectl patch deployment aurora-bridge -p '{"spec":{"replicas":2}}'

# 100% traffic (hour 12)
kubectl patch deployment aurora-bridge -p '{"spec":{"replicas":3}}'
kubectl scale deployment/aurora-bridge-v0 --replicas=0
```

### Post-Rollout Validation

```bash
# Verify all pods healthy
kubectl get pods -n aurora-production -l app=aurora-bridge

# Verify metrics flowing
curl http://prometheus:9090/api/v1/query?query=treaty_fill_rate

# Verify alerts configured
curl http://grafana:3000/api/v1/provisioning/alert-rules | grep Aurora

# Generate first production SLO report
python3 scripts/canary-slo-reporter.py --output reports/production-week1.json
```

---

## Phase 4: 30-Day Optimization

### Week 1: Tracing

```bash
# Enable Jaeger tracing
kubectl apply -f ops/k8s/jaeger/

# Verify trace IDs in receipts
cat artifacts/receipt-*.json | jq .trace_id
```

### Week 2: Credit Pricing Tuning

```bash
# Run simulator with production data
STEPS=1000 make sim-run

# Analyze fill rate vs price sensitivity
python3 scripts/analyze-pricing.py sim/out/routing_decisions.csv

# Adjust credit conversion rates
vim sim/multi-provider-routing-simulator/config/providers.json
```

### Week 3: Governance Cadence

```bash
# Generate 7-day SLO report
python3 scripts/canary-slo-reporter.py --output reports/week1-slo.json

# Generate weekly ledger snapshot
sqlite3 ops/data/remembrancer.db "SELECT * FROM audit_log WHERE timestamp > datetime('now', '-7 days');" > reports/week1-ledger.csv

# Sign and publish
gpg --detach-sign --armor reports/week1-slo.json
gpg --detach-sign --armor reports/week1-ledger.csv
```

### Week 4: External Audit Prep

```bash
# Generate evidence pack
mkdir -p audit/evidence-pack
cp dist/aurora-20251022.tar.gz audit/evidence-pack/
cp dist/aurora-20251022.tar.gz.asc audit/evidence-pack/
cp ops/data/remembrancer.db audit/evidence-pack/
cp reports/*.json audit/evidence-pack/
tar -czf audit/aurora-ga-evidence-pack.tar.gz audit/evidence-pack/

# Sign evidence pack
gpg --detach-sign --armor audit/aurora-ga-evidence-pack.tar.gz
```

---

## Surgical Hardening (Quick Wins)

### 1. ACK Signature Registry

```bash
# Document provider key registry
cat > docs/PROVIDER_KEY_REGISTRY.md << 'EOF'
# Provider Key Registry

## Akash Network
- Key ID: akash-provider-001
- Public Key: /ops/certs/akash-pubkey.pem
- Rotation: Quarterly (Jan/Apr/Jul/Oct)

## Rotation Procedure
1. Generate new keypair: `openssl genpkey -algorithm ED25519`
2. Distribute public key to all nodes
3. Update registry: `scripts/update-provider-key.sh`
4. Verify: `scripts/ack-verify.py --test`
EOF

git add docs/PROVIDER_KEY_REGISTRY.md
git commit -m "docs(aurora): add provider key registry and rotation procedure"
```

### 2. External Auditor Checklist

```bash
# Add evidence pack section to compliance annex
cat >> AURORA_GA_COMPLIANCE_ANNEX.md << 'EOF'

## Evidence Pack for External Auditors

All verification artifacts are bundled in `audit/aurora-ga-evidence-pack.tar.gz`:

- `aurora-20251022.tar.gz` — Release bundle
- `aurora-20251022.tar.gz.asc` — GPG signature
- `remembrancer.db` — Merkle audit database
- `*.tsr` — RFC3161 timestamp tokens
- `CHECKSUMS.txt` — SHA256 checksums
- `canary-72h.json` — Signed SLO report

**Verification:**
```bash
gpg --verify aurora-ga-evidence-pack.tar.gz.asc
tar -xzf aurora-ga-evidence-pack.tar.gz
bash scripts/verify-aurora-ga.sh
```
EOF

git add AURORA_GA_COMPLIANCE_ANNEX.md
git commit -m "docs(aurora): add external auditor evidence pack checklist"
```

---

## Monitoring & Alerts

### Critical Alerts (Pagerduty)

1. **FillRateLow** — Fill rate < 0.80 for 15m
2. **RTTHigh** — RTT > 350ms (p95) for 15m
3. **ProvenanceLow** — Coverage < 0.95 for 5m
4. **PolicyDecisionSlow** — Latency > 25ms (p99) for 5m

### Warning Alerts (Slack)

5. **CapacityLow** — Provider capacity < 20%
6. **ReputationDrop** — Provider reputation drops > 10 points

### Alert Verification

```bash
# Test alert firing
curl -X POST http://prometheus:9090/api/v1/admin/tsdb/delete_series \
  -d 'match[]=treaty_fill_rate{treaty_id="AURORA-AKASH-001"}'

# Verify Pagerduty integration
curl https://events.pagerduty.com/v2/enqueue \
  -H "Content-Type: application/json" \
  -d '{"routing_key":"<key>","event_action":"trigger","payload":{"summary":"Test alert","severity":"critical"}}'
```

---

## Success Metrics

### Technical KPIs

- Fill rate ≥ 0.85 (p50), ≥ 0.80 (p95)
- RTT ≤ 280ms (p50), ≤ 350ms (p95)
- Provenance coverage ≥ 0.95
- Policy latency ≤ 25ms (p99)
- Zero data loss (RPO 15m maintained)
- RTO < 1h for all incidents

### Operational KPIs

- Zero unplanned downtime
- < 2 SEV2 incidents per month
- 100% alert response within SLA
- Weekly governance reports published
- Monthly external audit readiness

### Business KPIs

- 10+ active treaties deployed
- 1000+ GPU hours routed
- 5+ provider integrations
- 95%+ customer satisfaction

---

## Rollback Plan

### Immediate Rollback (< 5 minutes)

```bash
# Revert to previous version
kubectl rollout undo deployment/aurora-bridge -n aurora-production

# Scale up backup deployment
kubectl scale deployment/aurora-bridge-backup --replicas=3 -n aurora-production

# Verify rollback
kubectl get pods -n aurora-production
curl http://aurora-bridge/health
```

### Data Recovery (< 1 hour)

```bash
# Restore from latest backup
aws s3 cp s3://vaultmesh-backups/ledger-$(date +%Y%m%d).db.gz .
gunzip ledger-$(date +%Y%m%d).db.gz
sqlite3 ops/data/remembrancer.db ".restore ledger-$(date +%Y%m%d).db"

# Verify integrity
./ops/bin/remembrancer verify-audit
```

---

## Next Steps

1. **Commit artifacts:**
   ```bash
   git add dist/VERIFICATION.md ops/grafana/grafana-kpi-panels-patch.json scripts/canary-slo-reporter.py scripts/verify-aurora-ga.sh
   git commit -m "chore(aurora): add GA deployment artifacts (verification, KPI panels, SLO reporter)"
   git push origin main
   ```

2. **Announce to operators:**
   - "Verification guide: `dist/VERIFICATION.md`"
   - "KPI dashboard: `ops/grafana/grafana-kpi-panels-patch.json`"
   - "SLO reporter: `scripts/canary-slo-reporter.py`"

3. **Start staging soak:**
   ```bash
   kubectl apply -k ops/k8s/overlays/staging
   make smoke-e2e
   ```

---

🜂 **The covenant is ready. The perimeter is locked. Begin deployment.**
