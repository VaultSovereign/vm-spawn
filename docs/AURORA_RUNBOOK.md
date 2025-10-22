# Aurora Treaty System - Operations Runbook

**Version**: RC1
**Last Updated**: 2025-10-22
**On-Call**: VaultMesh Sovereignty Ops

---

## Table of Contents

- [Emergency Contacts](#emergency-contacts)
- [System Overview](#system-overview)
- [SLOs & Thresholds](#slos--thresholds)
- [Operational Procedures](#operational-procedures)
- [Incident Response](#incident-response)
- [Monitoring & Alerts](#monitoring--alerts)
- [Maintenance](#maintenance)

---

## Emergency Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| On-Call Engineer | Pagerduty | Primary |
| Treaty Lead | Slack: #aurora-ops | Secondary |
| Security Team | security@vaultmesh.io | Critical |
| Provider Relations | providers@vaultmesh.io | Provider issues |

---

## System Overview

### Components

1. **vault-law Policy** (`policy/vault-law-akash-policy.rs`)
   - WASM-based enforcement engine
   - Enforces: quotas, regions, reputation, replay protection
   - SLO: ≤ 25ms decision latency (p95)

2. **Aurora Bridge** (Axelar/IBC)
   - Order submission endpoint
   - Schema + signature validation
   - SLO: ≤ 350ms RTT (p95)

3. **Provenance Layer** (`scripts/aurora-receipt-verify.sh`)
   - Merkle root + RFC3161 timestamp + IPFS pinning
   - SLO: ≥ 0.95 coverage

4. **Multi-Provider Router** (`sim/multi-provider-routing-simulator/`)
   - DePIN provider selection (7 providers)
   - SLO: ≥ 0.80 fill rate (p95)

5. **Metrics Exporters**
   - Aurora metrics: port 9109
   - Simulator metrics: port 9110

---

## SLOs & Thresholds

### Key Performance Indicators

| Metric | SLO | Alert Threshold | Critical Threshold |
|--------|-----|----------------|-------------------|
| Fill Rate | p50: ≥0.85, p95: ≥0.80 | <0.80 for 5m | <0.70 for 10m |
| Bridge RTT | p95: ≤350ms | >350ms for 10m | >500ms for 5m |
| Provenance Coverage | ≥0.95 | <0.90 for 15m | <0.80 for 10m |
| Policy Decision Time | p95: ≤25ms | >25ms for 10m | >50ms for 5m |
| Dropped Requests | <5% | >50 requests | >100 requests |
| Failover Events | <10 per 5m | >10 per 5m | >20 per 5m |

---

## Operational Procedures

### 1. Halt Treaty (Emergency)

**When to use**: Attestation failure, security breach, catastrophic provider issues

```bash
# Stop accepting new orders
kubectl scale deployment vm-spawn-gateway --replicas=0 -n aurora-akash

# Mark treaty as halted in policy
# TODO: Implement vault-law CLI
# vault-law halt --treaty AURORA-AKASH-001 --reason "attestation-failure"

# Notify stakeholders
echo "Treaty AURORA-AKASH-001 halted at $(date)" | \
  slack-send --channel "#aurora-ops"

# Create incident
# Follow incident management procedure
```

**Recovery**:
1. Investigate root cause
2. Verify all pending orders completed
3. Run integrity checks
4. Resume operations: `kubectl scale deployment vm-spawn-gateway --replicas=3`

---

### 2. Failover to Backup Provider

**When to use**: Primary provider outage, consistent rejections, SLA breaches

```bash
# Check provider health
curl -s http://prometheus:9090/api/v1/query \
  --data-urlencode 'query=provider_active{provider_id="akash"}' | jq .

# Update router weights (temporary)
# Edit: sim/multi-provider-routing-simulator/config/providers.json
# Increase weight for flux/vast/aethir

# Redeploy router configuration
kubectl rollout restart deployment vm-spawn-router -n aurora-akash

# Monitor fill rate
watch -n 10 'curl -s localhost:9109/metrics | grep fill_rate'
```

**Rollback**:
1. Verify primary provider health restored
2. Gradually shift traffic back (canary style)
3. Monitor for 1 hour before full restoration

---

### 3. Purge Nonce Cache (Replay Attack Response)

**When to use**: Suspected replay attack, nonce cache corruption, cache TTL issues

```bash
# Check nonce cache stats
python3 scripts/nonce-cache-helper.py stats

# Purge all nonces
python3 scripts/nonce-cache-helper.py clear

# Verify
python3 scripts/nonce-cache-helper.py stats

# Rotate signing keys (if compromise suspected)
./scripts/rotate-keys.sh

# Audit recent orders
psql aurora_db -c "SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '24 hours' ORDER BY created_at DESC LIMIT 100;"
```

---

### 4. Budget Exhaustion Recovery

**When to use**: Tenant hitting daily quota repeatedly, policy blocking legitimate traffic

```bash
# Check current usage
curl -s localhost:9109/metrics | grep tenant_id

# Temporary quota increase (requires policy update)
# Edit: templates/aurora-treaty-akash.json
# Update: quota_gpu_hours_daily_per_tenant

# Rebuild and redeploy policy
make policy-build
kubectl rollout restart deployment vault-law-engine -n aurora-akash

# Notify tenant
echo "Quota temporarily increased for tenant-42" | \
  notify-tenant --tenant tenant-42
```

---

### 5. Provenance Failure Recovery

**When to use**: TSA unreachable, IPFS pinning failures, Merkle root mismatches

```bash
# Check TSA health
curl -sS -H 'Content-Type: application/timestamp-query' \
  --data-binary @test.tsq https://freetsa.org/tsr

# Check IPFS health
ipfs swarm peers | wc -l

# Verify recent receipts
ls -lh /var/log/vm-spawn-job/*.receipt | tail -10

# Re-pin failed artifacts
for f in /var/log/vm-spawn-job/*.tgz; do
  bash scripts/aurora-receipt-verify.sh $(dirname $f) ${f%.tgz}.receipt.json
done

# Verify provenance coverage
curl -s localhost:9109/metrics | grep provenance_coverage
```

**Fail-closed behavior**: If provenance coverage < 0.80 for >10m, halt new allocations

---

## Incident Response

### Severity Levels

| Level | Definition | Response Time | Escalation |
|-------|-----------|---------------|------------|
| **SEV1** | Complete outage, security breach | 15 minutes | Immediate |
| **SEV2** | Partial outage, SLO breach | 1 hour | After 30m |
| **SEV3** | Degraded performance | 4 hours | After 2h |
| **SEV4** | Minor issue, no impact | 1 business day | None |

### Common Incidents

#### Incident: Low Fill Rate (<0.80)

**Possible Causes**:
- Provider capacity exhaustion
- Price spike making routes uneconomical
- Network partitions or bridge issues
- Unexpected tenant demand surge

**Diagnosis**:
```bash
# Check provider capacity
curl -s localhost:9110/metrics | grep provider_capacity

# Check routing decisions
tail -100 sim/multi-provider-routing-simulator/out/routing_decisions.csv | \
  awk -F, '{print $7}' | sort | uniq -c

# Check recent price changes
# (monitor external price feeds)
```

**Resolution**:
1. Identify bottleneck (capacity vs. price vs. latency)
2. If capacity: Enable additional providers or increase quotas
3. If price: Adjust budget thresholds or failover
4. If latency: Check bridge health, consider queue-and-retry

---

#### Incident: Bridge RTT Breach (>350ms)

**Possible Causes**:
- Axelar/IBC bridge slowness
- Network congestion
- Relayer issues
- DDoS attack

**Diagnosis**:
```bash
# Check Axelar bridge health
curl -s https://axelar.rpc/status | jq .

# Check IBC relayer
hermes health-check

# Network diagnostics
ping -c 10 axelar-bridge.example.com
traceroute axelar-bridge.example.com
```

**Resolution**:
1. If bridge issue: Contact Axelar team, consider failover bridge
2. If network: Check with ISP, consider VPN/tunnel
3. If DDoS: Enable rate limiting, contact security team
4. Temporary: Queue orders locally with exponential backoff

---

#### Incident: Provenance Coverage Low (<0.90)

**Possible Causes**:
- RFC3161 TSA unreachable
- IPFS pinning service down
- Receipt generation script errors
- Disk full on job nodes

**Diagnosis**:
```bash
# Check TSA
curl -I https://freetsa.org/tsr

# Check IPFS
ipfs id

# Check disk space
df -h /var/log/vm-spawn-job

# Check recent script errors
grep ERROR /tmp/aurora-receipt-*.log | tail -20
```

**Resolution**:
1. If TSA down: Failover to backup TSA (timestamping.org)
2. If IPFS down: Restart daemon, check peers
3. If disk full: Clean old artifacts, expand volume
4. If script errors: Debug and patch `scripts/aurora-receipt-verify.sh`

**Critical**: Halt new allocations if coverage < 0.80

---

## Monitoring & Alerts

### Alert Rules

See: `ops/grafana/aurora-alert-rules.yaml`

**Alert Flow**:
1. Prometheus scrapes metrics (9109, 9110)
2. Grafana evaluates alert rules (1m interval)
3. Alertmanager routes to Pagerduty/Slack
4. On-call engineer acknowledges within SLA

### Dashboards

**Primary**: `Aurora Treaty – Akash KPIs`
- Fill Rate (stat)
- Provenance Coverage (stat)
- Law-Bridge RTT (gauge)
- GPU Hours Consumed (timeseries)
- Dropped Requests (stat)
- Provider Failover Events (timeseries)

**Secondary**: Provider Health Dashboard
- Per-provider capacity, latency, price, reputation

### Log Aggregation

```bash
# View aggregated logs
kubectl logs -l treaty_id=AURORA-AKASH-001 -n aurora-akash --tail=100 -f

# Search for errors
kubectl logs -l treaty_id=AURORA-AKASH-001 -n aurora-akash | grep -i error

# Filter by tenant
kubectl logs -l treaty_id=AURORA-AKASH-001 -n aurora-akash | grep tenant-42
```

---

## Maintenance

### Routine Tasks

**Daily**:
- [ ] Review alert history
- [ ] Check SLO compliance
- [ ] Verify backup status

**Weekly**:
- [ ] Review capacity trends
- [ ] Update provider key registry
- [ ] Audit recent orders for anomalies
- [ ] Run war-game scenarios in simulator

**Monthly**:
- [ ] Policy review and optimization
- [ ] Provider onboarding/offboarding
- [ ] Security audit (keys, certificates, access)
- [ ] Performance tuning

### Deployment Procedure

```bash
# 1. Pre-deployment checks
make treaty-verify
make policy-build
python3 sim/multi-provider-routing-simulator/sim/test_router.py

# 2. Staging deployment
kubectl apply -f ops/k8s/ --dry-run=client
kubectl apply -f ops/k8s/ -n aurora-akash-staging

# 3. Smoke test
bash scripts/smoke-e2e.sh

# 4. Production deployment (canary)
kubectl set image deployment/vm-spawn-gateway gateway=vaultmesh/gateway:v1.2.0 -n aurora-akash
kubectl rollout status deployment/vm-spawn-gateway -n aurora-akash

# 5. Monitor for 1 hour
watch -n 30 'curl -s localhost:9109/metrics | grep fill_rate'

# 6. Full rollout or rollback
kubectl rollout undo deployment/vm-spawn-gateway -n aurora-akash  # if issues
```

### Backup & Recovery

**Backup Locations**:
- Policy WASM: `s3://vaultmesh-policies/aurora/`
- Receipts: `s3://vaultmesh-receipts/aurora/`
- Configuration: Git repository (tagged releases)
- Keys: Hardware Security Module (HSM)

**Recovery Time Objective (RTO)**: 1 hour
**Recovery Point Objective (RPO)**: 15 minutes

---

## Troubleshooting

### Quick Diagnostics

```bash
# All-in-one health check
scripts/smoke-e2e.sh

# Check all services
kubectl get pods -n aurora-akash

# Recent errors
kubectl logs -l treaty_id=AURORA-AKASH-001 --tail=50 | grep -i error

# Metrics snapshot
curl -s localhost:9109/metrics | grep -E "(fill_rate|rtt_ms|provenance)"
```

### Common Issues

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| Pods CrashLoopBackOff | Missing secrets | Check `kubectl get secrets` |
| High latency | Bridge congestion | Enable queue-and-retry |
| 401 errors | Invalid signatures | Rotate keys, verify clock sync |
| 422 errors | Schema validation | Check order format vs. schema |
| Fill rate drop | Provider outage | Failover to backup |

---

## Appendices

### A. Key File Locations

```
policy/
  vault-law-akash-policy.rs     - Policy source
  wasm/                          - Compiled WASM modules
scripts/
  aurora-receipt-verify.sh       - Provenance generation
  nonce-cache-helper.py          - Replay protection
  ack-verify.py                  - ACK signature verification
  policy-host-adapter.py         - WASM execution
ops/
  k8s/vm-spawn-llm-infer.yaml    - Job template
  grafana/aurora-alert-rules.yaml - Alert rules
templates/
  aurora-treaty-akash.json       - Treaty definition
```

### B. Useful Commands

```bash
# Policy
make policy-build
python3 scripts/policy-host-adapter.py policy/wasm/*.wasm policy/test.json

# Nonce cache
python3 scripts/nonce-cache-helper.py check --nonce test-001
python3 scripts/nonce-cache-helper.py stats

# ACK verification
python3 scripts/ack-verify.py ack.json --treaty-id AURORA-AKASH-001 --provider-id akash-main

# Simulator
SEED=99 STEPS=120 make sim-run
make sim-metrics-run

# Metrics
curl -s localhost:9109/metrics
curl -s localhost:9110/metrics
```

---

**Document Owner**: VaultMesh Sovereignty Ops
**Review Cycle**: Monthly
**Last Incident**: None (RC1 baseline)
**Next Review**: 2025-11-22
