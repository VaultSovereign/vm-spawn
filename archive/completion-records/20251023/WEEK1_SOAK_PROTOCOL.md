# Week 1 Soak Protocol — Aurora GA v1.0.0

**Start Date:** 2025-10-22  
**Status:** 🜂 INITIATED  
**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

---

## Observatory Setup (Next 24h)

### 1. Deploy Prometheus
```bash
# Create config
cat > ops/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'aurora-metrics'
    static_configs:
      - targets: ['localhost:9109']
        labels:
          treaty_id: 'AURORA-AKASH-001'
  
  - job_name: 'simulator-metrics'
    static_configs:
      - targets: ['localhost:9110']
        labels:
          component: 'simulator'
EOF

# Start Prometheus
docker run -d --name prometheus \
  -p 9090:9090 \
  -v $(pwd)/ops/prometheus.yml:/etc/prometheus/prometheus.yml \
  --network host \
  prom/prometheus
```

### 2. Deploy Grafana
```bash
docker run -d --name grafana \
  -p 3000:3000 \
  grafana/grafana

# Import dashboard
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @ops/grafana/grafana-kpi-panels-patch.json

# Import alerts
curl -X POST http://admin:admin@localhost:3000/api/v1/provisioning/alert-rules \
  -H "Content-Type: application/json" \
  -d @ops/grafana/aurora-alert-rules.yaml
```

### 3. Verify Data Flow
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'

# Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=treaty_fill_rate' | jq

# Check Grafana panels (should light up within 30s)
open http://localhost:3000
```

---

## Daily Protocol (7 Days)

### Morning (09:00)
```bash
# 1. Run smoke test
make smoke-e2e | tee logs/smoke-$(date +%Y%m%d).log

# 2. Backup ledger
mkdir -p ops/backups
sqlite3 ops/data/remembrancer.db ".backup ops/backups/ledger-$(date +%Y%m%d).db"
gzip ops/backups/ledger-$(date +%Y%m%d).db

# 3. Check SLOs
curl -s 'http://localhost:9090/api/v1/query?query=treaty_fill_rate{treaty_id="AURORA-AKASH-001"}' | jq '.data.result[0].value[1]'
```

### Midday (12:00)
```bash
# Verify metrics endpoint
curl http://localhost:9109/metrics | grep -E 'treaty_fill_rate|treaty_rtt_ms'

# Check for anomalies
curl -s 'http://localhost:9090/api/v1/query?query=rate(treaty_dropped_requests_total[5m])' | jq
```

### Evening (18:00)
```bash
# Generate daily report
python3 scripts/canary-slo-reporter.py \
  --prometheus http://localhost:9090 \
  --output reports/daily-$(date +%Y%m%d).json \
  --no-sign

# Archive logs
tar czf metrics-$(date +%Y%m%d).tar.gz logs/ ops/backups/
```

### Night (23:59)
```bash
# Final health check
./ops/bin/health-check

# Verify Merkle integrity
./ops/bin/remembrancer verify-audit
```

---

## SLO Targets (Continuous Monitoring)

| Metric | Target | Query |
|--------|--------|-------|
| Fill Rate (p95) | ≥ 0.80 | `histogram_quantile(0.95, treaty_fill_rate_bucket)` |
| RTT (p95) | ≤ 350ms | `histogram_quantile(0.95, treaty_rtt_ms_bucket)` |
| Provenance | ≥ 0.95 | `treaty_provenance_coverage` |
| Policy Latency (p99) | ≤ 25ms | `histogram_quantile(0.99, policy_decision_ms_bucket)` |

**Alert if:**
- Fill rate < 0.75 for 15 consecutive minutes
- RTT > 400ms (p95) for 15 consecutive minutes
- Provenance < 0.90 for 5 minutes
- Policy latency > 50ms (p99) for 5 minutes

---

## Hour 72 Governance Report

```bash
# Generate signed report
python3 scripts/canary-slo-reporter.py \
  --prometheus http://localhost:9090 \
  --output reports/canary-72h.json \
  --key 6E4082C6A410F340

# Verify signature
gpg --verify reports/canary-72h.json.asc reports/canary-72h.json

# Attach to governance docket:
# - canary-72h.json + .asc
# - Checksum: acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8
# - Merkle root snapshot
# - 72h metrics archive
```

---

## Day 7 Transition Checklist

- [ ] 7 consecutive days of smoke tests passed
- [ ] All SLOs met for 168 hours
- [ ] Zero SEV1/SEV2 incidents
- [ ] Ledger backups complete (7 snapshots)
- [ ] Governance report signed and filed
- [ ] Grafana alerts validated
- [ ] Runbook procedures tested

**Upon completion:** Transition to canary rollout (10% traffic)

---

## Emergency Procedures

### Immediate Rollback
```bash
# Stop services
pkill -f aurora-mock
pkill -f aurora-metrics-exporter

# Restore from backup
gunzip ops/backups/ledger-latest.db.gz
sqlite3 ops/data/remembrancer.db ".restore ops/backups/ledger-latest.db"
```

### Data Recovery
```bash
# Verify backup integrity
sqlite3 ops/backups/ledger-$(date +%Y%m%d).db "PRAGMA integrity_check;"

# Restore specific table
sqlite3 ops/data/remembrancer.db ".dump audit_log" | sqlite3 ops/backups/audit_log_backup.db
```

---

## Monitoring Endpoints

- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000 (admin/admin)
- **Aurora Metrics:** http://localhost:9109/metrics
- **Simulator Metrics:** http://localhost:9110/metrics
- **Mock Bridge:** http://localhost:8080

---

## Success Criteria

### Technical
- Fill rate ≥ 0.85 (p50), ≥ 0.80 (p95)
- RTT ≤ 280ms (p50), ≤ 350ms (p95)
- Provenance coverage ≥ 0.95
- Policy latency ≤ 25ms (p99)
- Zero data loss (RPO 15m maintained)

### Operational
- 7/7 daily smoke tests passed
- 7/7 ledger backups completed
- 100% alert response within SLA
- Runbook procedures validated
- Governance report filed

---

🜂 **The 7-day watch begins. The network breathes. The law observes.**
