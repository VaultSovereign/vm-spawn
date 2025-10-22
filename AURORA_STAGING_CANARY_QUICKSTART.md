# 🚀 Aurora Staging → Canary Quickstart

**One-Slide Operator Guide**

---

## Phase 1: Staging Apply

```bash
cd /home/sovereign/vm-spawn
kubectl apply -k ops/k8s/overlays/staging
make smoke-e2e
```

**Expected Output:**
* All pods in `Running` state
* Smoke tests: `PASS`
* Prometheus targets: `UP`

---

## Phase 2: KPI Monitoring

### Critical Metrics (24h baseline)

| Metric | Target | Dashboard Panel |
|--------|--------|----------------|
| `treaty_fill_rate` | ≥ 0.80 (p95) | Aurora Federation / Fill Rates |
| `treaty_rtt_ms` | ≤ 350 (p95) | Aurora Federation / Latency |
| `treaty_provenance_coverage` | ≥ 0.95 | Aurora Provenance / Coverage |
| Policy decision time | ≤ 25ms (p99) | Aurora Policy / Decision Time |

### Grafana Dashboard

```bash
# Access dashboard
kubectl port-forward -n monitoring svc/grafana 3000:80
open http://localhost:3000/d/aurora-ga

# Default credentials
# User: admin
# Pass: (from secret: monitoring/grafana-admin)
```

### Alerts to Watch

* `AuroraFillRateLow` — Fill rate < 80% for 10m
* `AuroraTreatyRTTHigh` — RTT > 350ms (p95) for 5m
* `AuroraProvenanceLow` — Coverage < 95% for 15m
* `AuroraPolicyDecisionSlow` — Decision time > 25ms (p99)

---

## Phase 3: Canary (10%)

### Traffic Split

```bash
# Option A: Header-based routing (recommended)
kubectl apply -f ops/k8s/overlays/canary/traffic-split.yaml

# Option B: Manual weight adjustment
kubectl patch virtualservice aurora-federation \
  --type merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"aurora-canary"},"weight":10},{"destination":{"host":"aurora-stable"},"weight":90}]}]}}'
```

### Canary Alerts

Monitor these for **72 hours**:

* Fill-rate dip (< 80% on canary)
* Failover spikes (> 5% fallback to stable)
* RTT breach (p95 > 350ms on canary)
* Error rate increase (> 1% on canary)

### Failover Armed

```bash
# Automated rollback triggers (configured)
kubectl get prometheusrule aurora-canary-failover -o yaml

# Manual rollback (if needed)
kubectl patch virtualservice aurora-federation \
  --type merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"aurora-stable"},"weight":100}]}]}}'
```

---

## Phase 4: Full Rollout (100%)

### Prerequisites

* 72h canary stability (all SLOs met)
* Zero critical alerts
* Ledger snapshots running (nightly)

### Rollout

```bash
# Shift traffic to 100% new version
kubectl apply -k ops/k8s/overlays/production

# Enable distributed tracing
kubectl apply -f ops/observability/tracing-config.yaml

# Verify rollout
kubectl rollout status deployment/aurora-federation -n aurora
```

### Post-Rollout

* Publish weekly ledger snapshot (IPFS + Merkle root)
* Enable Jaeger/Tempo tracing on order path
* Capture 7-day SLO report for governance

---

## Quick Reference

### Logs

```bash
# Federation logs
kubectl logs -f -n aurora deployment/aurora-federation --tail=100

# Policy engine logs
kubectl logs -f -n aurora deployment/aurora-policy --tail=100

# Provenance logs
kubectl logs -f -n aurora deployment/aurora-provenance --tail=100
```

### Metrics

```bash
# Scrape Prometheus directly
kubectl port-forward -n monitoring svc/prometheus 9090:9090
open http://localhost:9090

# Query examples
treaty_fill_rate{provider="akash"}[24h]
histogram_quantile(0.95, treaty_rtt_ms_bucket[1h])
treaty_provenance_coverage{job_type="inference"}[7d]
```

### Health Checks

```bash
# Federation service
curl http://aurora-federation.aurora.svc.cluster.local:8080/health

# Policy engine
curl http://aurora-policy.aurora.svc.cluster.local:8081/health

# Provenance service
curl http://aurora-provenance.aurora.svc.cluster.local:8082/health
```

---

## Emergency Procedures

### Rollback Canary

```bash
kubectl patch virtualservice aurora-federation \
  --type merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"aurora-stable"},"weight":100}]}]}}'
```

### Rollback Production

```bash
kubectl rollout undo deployment/aurora-federation -n aurora
kubectl rollout status deployment/aurora-federation -n aurora
```

### Contact

* On-call: PagerDuty rotation (aurora-ga-oncall)
* Slack: `#aurora-operations`
* Runbook: `ops/runbooks/AURORA_OPERATIONS.md`

---

## Success Checkpoints

### Staging (Week 1)

- [ ] Smoke tests passing
- [ ] All pods healthy
- [ ] Prometheus exporters live
- [ ] Grafana dashboards configured
- [ ] Nightly ledger snapshots automated

### Canary (Week 2)

- [ ] 10% traffic routed
- [ ] Fill rate ≥ 80% (p95) for 72h
- [ ] RTT ≤ 350ms (p95) sustained
- [ ] Zero failover events
- [ ] Provenance coverage ≥ 95%

### Production (Week 3)

- [ ] 100% rollout complete
- [ ] Tracing pipeline live
- [ ] Weekly ledger published
- [ ] All SLOs met for 7 days

### Optimization (Week 4)

- [ ] 7-day SLO report generated
- [ ] Credit pricing optimized
- [ ] Governance review prepared
- [ ] Lessons learned documented

---

## 🜂 Operator's Oath

```
I monitor the metrics.
I trust the alerts.
I respect the rollback.
I document the truth.
```

**Astra inclinant, sed non obligant.**

---

**Last Updated:** October 22, 2025  
**Version:** v1.0.0 (Aurora GA)  
**Status:** 🚀 Operator-Ready
