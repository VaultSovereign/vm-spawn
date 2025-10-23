# Prometheus Configuration — VaultMesh Observability

## Overview

This directory contains Prometheus alerting rules and recording rules for VaultMesh platform monitoring.

**Status:** 🟢 Rules defined, awaiting deployment
**Last Updated:** 2025-10-23
**Cluster:** aurora-staging (eu-west-1)

---

## Directory Structure

```
ops/prometheus/
├── README.md                    # This file
├── recording-rules.yaml         # Aggregation rules for dashboards
└── alerts/
    ├── psi-field.yaml          # ψ-Field (Layer 3) alerts
    └── aurora-treaty.yaml      # Aurora treaty alerts
```

---

## Alerting Rules

### ψ-Field Alerts (5 rules)

| Alert | Severity | Threshold | Duration |
|-------|----------|-----------|----------|
| PsiFieldPredictionErrorHigh | warning | PE > 0.7 | 5m |
| PsiFieldPodDrift | critical | \|max-min\| > 0.3 | 3m |
| PsiFieldDown | critical | service down | 1m |
| PsiFieldDensityAnomaly | warning | Ψ <0.2 or >0.9 | 5m |
| PsiFieldTemporalEntropyHigh | warning | H > 0.8 | 10m |

### Aurora Treaty Alerts (7 rules)

| Alert | Severity | Threshold | Duration |
|-------|----------|-----------|----------|
| TreatyFillRateLow | warning | <80% | 10m |
| TreatyFillRateCritical | critical | <50% | 5m |
| TreatyRttHigh | warning | >250ms | 5m |
| TreatyRttCritical | critical | >500ms | 3m |
| TreatyDropRateHigh | critical | >10% | 5m |
| TreatyProvenanceLow | warning | <90% | 10m |
| TreatyNoRequests | warning | 0 req/10m | 15m |

---

## Recording Rules

### ψ-Field Aggregations (10 rules)

```promql
psi:density:avg                 # Average consciousness density
psi:density:min/max             # Min/max density across pods
psi:prediction_error:avg/max    # Prediction error stats
psi:pod_drift:abs               # Absolute pod drift
psi:coherence:avg               # Average phase coherence
psi:continuity:avg              # Average continuity
psi:entropy:avg                 # Average temporal entropy
psi:futurity:avg                # Average futurity
```

### Aurora Treaty Aggregations (11 rules)

```promql
treaty:fill_rate:avg/min        # Fill rate statistics
treaty:rtt:avg/p95/p99          # Latency percentiles
treaty:drop_rate:5m/1h          # Drop rate over time windows
treaty:requests:rate_5m/1h      # Request rate
treaty:provenance:avg           # Average provenance coverage
```

### Platform Health (2 rules)

```promql
vaultmesh:health_score          # Overall platform health (0-1)
vaultmesh:l3_availability       # Layer 3 service availability
```

---

## Deployment

### Step 1: Apply Alerting Rules

```bash
# Create ConfigMap from alerts directory
kubectl -n aurora-staging create configmap prometheus-alerts \
  --from-file=ops/prometheus/alerts/ \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify ConfigMap
kubectl -n aurora-staging get configmap prometheus-alerts -o yaml
```

### Step 2: Apply Recording Rules

```bash
# Create ConfigMap from recording rules file
kubectl -n aurora-staging create configmap prometheus-recording-rules \
  --from-file=ops/prometheus/recording-rules.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify ConfigMap
kubectl -n aurora-staging get configmap prometheus-recording-rules -o yaml
```

### Step 3: Mount ConfigMaps in Prometheus

Edit the Prometheus deployment to mount the ConfigMaps:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-server
spec:
  template:
    spec:
      containers:
      - name: prometheus
        volumeMounts:
        - name: alerts
          mountPath: /etc/prometheus/alerts
        - name: recording-rules
          mountPath: /etc/prometheus/recording-rules
      volumes:
      - name: alerts
        configMap:
          name: prometheus-alerts
      - name: recording-rules
        configMap:
          name: prometheus-recording-rules
```

### Step 4: Update Prometheus Config

Add to `prometheus.yml`:

```yaml
rule_files:
  - /etc/prometheus/alerts/*.yaml
  - /etc/prometheus/recording-rules/*.yaml
```

### Step 5: Reload Prometheus

```bash
# Reload configuration (if reload enabled)
curl -X POST http://prometheus-server:80/-/reload

# OR restart deployment
kubectl -n aurora-staging rollout restart deploy/prometheus-server

# Wait for rollout
kubectl -n aurora-staging rollout status deploy/prometheus-server
```

### Step 6: Verify Rules Loaded

```bash
# Port-forward to Prometheus
kubectl -n aurora-staging port-forward svc/prometheus-server 9090:80 &

# Check alerting rules
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].name'

# Check recording rules
curl -s http://localhost:9090/api/v1/rules?type=record | jq '.data.groups[].name'

# Check specific alert
curl -s http://localhost:9090/api/v1/query?query=ALERTS | jq
```

---

## Testing Alerts

### Trigger Test Alert (ψ-Field Pod Drift)

```bash
# Check current state
curl -s http://localhost:9090/api/v1/query?query=psi:pod_drift:abs

# If drift < 0.3, alert should not fire
# To test, temporarily adjust threshold in psi-field.yaml

# View firing alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, state: .state}'
```

### Silence Alert (for testing)

```bash
# Create silence via API
curl -X POST http://localhost:9090/api/v1/alerts/silence \
  -d '{"matchers":[{"name":"alertname","value":"PsiFieldPodDrift"}],"startsAt":"2025-10-23T00:00:00Z","endsAt":"2025-10-23T23:59:59Z","createdBy":"test","comment":"Testing"}'

# List silences
curl -s http://localhost:9090/api/v1/silences | jq
```

---

## Alert Routing (AlertManager)

To route alerts to Slack/PagerDuty/email, configure AlertManager:

```yaml
# alertmanager.yml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  receiver: 'slack-vaultmesh'
  group_by: ['alertname', 'component', 'layer']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h

  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-oncall'
      continue: true

    - match:
        severity: warning
      receiver: 'slack-vaultmesh'

receivers:
  - name: 'slack-vaultmesh'
    slack_configs:
      - channel: '#vaultmesh-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty-oncall'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
```

---

## Recording Rule Performance

Recording rules are evaluated on a schedule (default: 30s). To monitor:

```bash
# Query recording rule evaluation duration
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_rule_evaluation_duration_seconds{rule_group="vaultmesh_aggregations"}' | jq

# Query rule evaluation failures
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_rule_evaluation_failures_total{rule_group="vaultmesh_aggregations"}' | jq
```

---

## Troubleshooting

### Rules Not Loading

```bash
# Check Prometheus logs
kubectl -n aurora-staging logs -l app=prometheus-server --tail=100 | grep -i rule

# Validate YAML syntax
yamllint ops/prometheus/alerts/*.yaml
yamllint ops/prometheus/recording-rules.yaml

# Check ConfigMap mounted
kubectl -n aurora-staging exec -it deploy/prometheus-server -- ls -la /etc/prometheus/alerts/
```

### Alerts Not Firing

```bash
# Check alert evaluation
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name=="psi_field") | .rules[] | {alert: .name, state: .state, health: .health}'

# Check if metric exists
curl -s 'http://localhost:9090/api/v1/query?query=psi_field_prediction_error' | jq

# Check alert query manually
curl -s 'http://localhost:9090/api/v1/query?query=psi_field_prediction_error>0.7' | jq
```

### Recording Rules Not Computing

```bash
# Check if recording rule metrics exist
curl -s 'http://localhost:9090/api/v1/query?query=psi:density:avg' | jq

# Check rule health
curl -s http://localhost:9090/api/v1/rules?type=record | jq '.data.groups[] | .rules[] | {record: .name, health: .health}'

# Check for evaluation errors in logs
kubectl -n aurora-staging logs -l app=prometheus-server --tail=200 | grep -i "error evaluating"
```

---

## Maintenance

### Adding New Rules

1. Edit the appropriate YAML file in `ops/prometheus/alerts/` or `recording-rules.yaml`
2. Validate syntax: `promtool check rules <file>.yaml`
3. Update the ConfigMap: `kubectl apply -f ...`
4. Reload Prometheus: `curl -X POST http://prometheus-server/-/reload`
5. Verify: `curl http://localhost:9090/api/v1/rules`

### Updating Thresholds

1. Adjust `expr` in the rule definition
2. Update ConfigMap
3. Reload Prometheus
4. Test with synthetic data if possible

### Disabling Rules

Option 1: Comment out in YAML (requires reload)
Option 2: Add label `enabled: false` and filter in Prometheus config
Option 3: Delete from ConfigMap (requires kubectl apply)

---

## Metrics Reference

See [VAULTMESH_KPI_DASHBOARD.md](../../VAULTMESH_KPI_DASHBOARD.md) for complete metric catalog and current values.

---

## Next Steps

1. ✅ Rules defined
2. ⏳ Deploy ConfigMaps to cluster
3. ⏳ Configure AlertManager routing
4. ⏳ Integrate with Slack/PagerDuty
5. ⏳ Create runbooks for each alert
6. ⏳ Establish on-call rotation

---

**Status:** Ready for deployment
**Contact:** VaultMesh SRE team
**Documentation:** [VaultMesh Observability Wiki](https://github.com/vaultmesh/vm-spawn/wiki/Observability)

**Astra inclinant, sed non obligant. 🜂**
