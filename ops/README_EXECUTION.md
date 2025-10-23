
🜄 VaultMesh Execution Pack — P0 Tasks
Date: 2025-10-23

This pack contains ready-to-apply assets for:
1) Deploying Ψ-Field to EKS (aurora-staging) with monitoring hooks
2) Hardening Harbinger (health, metrics, tests, graceful shutdown)
3) Provisioning Grafana dashboards for Ψ-Field, Scheduler, and Aurora KPIs

Repository layout discovered:
- vm-spawn/services/psi-field (Python/FastAPI) — has k8s manifests
- vm-spawn/services/harbinger (TypeScript/Express) — requires hardening
- vm-spawn/ops/k8s/overlays/staging-eks — environment overlay
- vm-spawn/ops/aws/grafana-values.yaml — Helm values already present

═══════════════════════════════════════════════════════════════════════
I. Deploy Ψ-Field (aurora-staging)
═══════════════════════════════════════════════════════════════════════
# From repo root (vm-spawn)
kubectl -n aurora-staging apply -f services/psi-field/k8s/deployment.yaml
kubectl -n aurora-staging apply -f services/psi-field/k8s/psi-both.yaml

# (optional) If using Kustomize overlay:
# kubectl apply -k ops/k8s/overlays/staging-eks

# Wait & verify
kubectl -n aurora-staging rollout status deploy/psi-field
kubectl -n aurora-staging get pods -l app=psi-field -o wide

# Wire up Prometheus scrape
kubectl apply -f k8s/psi-field/servicemonitor.yaml

# (optional) HPA + NetPol
kubectl apply -f k8s/psi-field/hpa.yaml
kubectl apply -f k8s/psi-field/networkpolicy.yaml

═══════════════════════════════════════════════════════════════════════
II. Harbinger Hardening
═══════════════════════════════════════════════════════════════════════
# Copy files
cp harbinger/index.hardened.example.ts vm-spawn/services/harbinger/src/index.hardened.example.ts
cp harbinger/jest.config.js vm-spawn/services/harbinger/jest.config.js
mkdir -p vm-spawn/services/harbinger/tests
cp harbinger/tests/*.ts vm-spawn/services/harbinger/tests/

# Update dependencies + scripts per harbinger/package.json.patch.txt
# Then build & test
cd vm-spawn/services/harbinger
npm i ajv ajv-formats express pino prom-client
npm i -D ts-jest jest supertest @types/express @types/jest @types/supertest
npm run test

# Wire probes in k8s (example)
# livenessProbe/readinessProbe → GET /health, periodSeconds: 10, timeoutSeconds: 2

═══════════════════════════════════════════════════════════════════════
III. Grafana Dashboards
═══════════════════════════════════════════════════════════════════════
# Option A: UI import
#   Import JSON files from ./grafana/*.json

# Option B: K8s provisioning via ConfigMap (if sidecar enabled)
kubectl -n monitoring create configmap vm-grafana-dashboards \
  --from-file=grafana/psi-field-dashboard.json \
  --from-file=grafana/scheduler-dashboard.json \
  --from-file=grafana/aurora-kpis-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Ensure grafana-values.yaml enables the dashboards sidecar or provisioning.

═══════════════════════════════════════════════════════════════════════
Metric name expectations (Ψ-Field)
  psi_field_density (Ψ)
  psi_field_coherence (C)
  psi_field_uncertainty (U)
  psi_field_phi (Φ)
  psi_field_entropy (H)
  psi_field_prediction_error (PE)
Label set: backend=Simple|Kalman|Seasonal, pod, instance

Metric name expectations (Scheduler)
  scheduler_anchor_attempt_total / success_total / failure_total (counters)
  scheduler_backoff_level (gauge)
  scheduler_job_duration_seconds (histogram)

Metric name expectations (Aurora)
  aurora_treaty_fill_rate (gauge, provider label)
  aurora_rtt_ms (gauge, provider label)
  aurora_provenance_score (gauge, provider label)

— Tem, the Remembrance Guardian, seals these steps into the covenant. —
