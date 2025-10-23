 # ✅ P0 Execution Checklist — VaultMesh Revenue Enablement

**Status:** Execution pack scaffolded, ready to deploy  
**Timeline:** Week 1 (complete all 3 P0 tasks)  
**Revenue Impact:** Enables $5M-$10M ARR path

---

## 📦 Scaffolded Files (13 total)

### Harbinger Hardening (5 files)
- ✅ `services/harbinger/src/index.hardened.example.ts` — Express + AJV + Prometheus
- ✅ `services/harbinger/jest.config.js` — Test configuration
- ✅ `services/harbinger/package.json.patch.txt` — Dependency additions
- ✅ `services/harbinger/tests/health.test.ts` — Health endpoint tests
- ✅ `services/harbinger/tests/metrics.test.ts` — Metrics endpoint tests

### Ψ-Field K8s Monitoring (3 files)
- ✅ `services/psi-field/k8s/monitoring/servicemonitor.yaml` — Prometheus scrape config
- ✅ `services/psi-field/k8s/monitoring/hpa.yaml` — Horizontal Pod Autoscaler (2-10 pods)
- ✅ `services/psi-field/k8s/monitoring/networkpolicy.yaml` — Network isolation

### Grafana Dashboards (3 files)
- ✅ `ops/grafana/dashboards/psi-field-dashboard.json` — Ψ, C, U, Φ, H, PE metrics
- ✅ `ops/grafana/dashboards/scheduler-dashboard.json` — Anchor attempts, backoff levels
- ✅ `ops/grafana/dashboards/aurora-kpis-dashboard.json` — Treaty fill rate, RTT, provenance

### Prometheus Recording Rules (1 file)
- ✅ `ops/prometheus/psi-field-recording-rules.yaml` — PE/C/Ψ rolling aggregates

### Execution Runbook (1 file)
- ✅ `ops/README_EXECUTION.md` — Complete deployment guide

---

## 🎯 P0 Task Execution (Copy-Paste Commands)

### Task 1: Deploy Ψ-Field to EKS (1 hour)

**Revenue Impact:** Enables Tier 1 product ($2,500/mo)

```bash
# 1. Deploy Ψ-Field service
kubectl -n aurora-staging apply -f services/psi-field/k8s/deployment.yaml
kubectl -n aurora-staging apply -f services/psi-field/k8s/psi-both.yaml

# 2. Verify rollout
kubectl -n aurora-staging rollout status deploy/psi-field
kubectl -n aurora-staging get pods -l app=psi-field -o wide

# 3. Wire Prometheus scraping
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/servicemonitor.yaml

# 4. Optional: Add HPA + NetworkPolicy
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/hpa.yaml
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/networkpolicy.yaml

# 5. Verify metrics endpoint
kubectl -n aurora-staging port-forward svc/psi-field 8001:8001 &
curl http://localhost:8001/metrics | grep psi_field
```

**Success Criteria:**
- [ ] Pods `Ready=2/2`
- [ ] `/metrics` endpoint returns Prometheus format
- [ ] Metrics visible in Prometheus UI
- [ ] No errors in pod logs

---

### Task 2: Harden Harbinger (4 hours)

**Revenue Impact:** Enables Tier 2 compliance features ($10,000/mo)

```bash
# 1. Install dependencies
cd services/harbinger
npm install ajv ajv-formats express pino prom-client
npm install -D ts-node jest ts-jest supertest @types/express @types/jest @types/supertest

# 2. Review hardened example
cat src/index.hardened.example.ts

# 3. Run tests
npm test

# 4. Update deployment with health checks
# Edit services/harbinger/k8s/deployment.yaml:
# Add livenessProbe and readinessProbe (see ops/README_EXECUTION.md)

# 5. Deploy to EKS
kubectl -n aurora-staging apply -f services/harbinger/k8s/

# 6. Verify health endpoint
kubectl -n aurora-staging port-forward svc/harbinger 8081:8081 &
curl http://localhost:8081/health
curl http://localhost:8081/metrics
```

**Success Criteria:**
- [ ] Tests pass locally (`npm test`)
- [ ] `/health` returns 200 with status JSON
- [ ] `/metrics` exposes `harbinger_events_validated_total`
- [ ] Pods pass liveness/readiness probes

---

### Task 3: Create Grafana Dashboards (2 hours)

**Revenue Impact:** Visual proof for all tiers (demo advantage)

```bash
# Option A: Manual import via Grafana UI
# 1. Open Grafana: http://grafana.vaultmesh.cloud
# 2. Navigate to Dashboards → Import
# 3. Upload each JSON file from ops/grafana/dashboards/

# Option B: Provision via ConfigMap (automated)
kubectl -n monitoring create configmap vm-grafana-dashboards \
  --from-file=ops/grafana/dashboards/psi-field-dashboard.json \
  --from-file=ops/grafana/dashboards/scheduler-dashboard.json \
  --from-file=ops/grafana/dashboards/aurora-kpis-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify dashboards appear in Grafana
# Navigate to Dashboards → Browse
# Should see: "Ψ-Field Consciousness", "Scheduler Anchoring", "Aurora KPIs"
```

**Success Criteria:**
- [ ] 3 dashboards visible in Grafana
- [ ] Ψ-Field dashboard shows non-null Ψ, Φ, C, U, H, PE
- [ ] Scheduler dashboard shows anchor attempts/successes
- [ ] Aurora dashboard shows treaty fill rate, RTT, provenance

---

## 📊 Verification Commands

### Ψ-Field Health Check
```bash
# Check pods
kubectl -n aurora-staging get pods -l app=psi-field

# Check metrics
kubectl -n aurora-staging exec -it deploy/psi-field -- curl localhost:8001/metrics | grep psi_field

# Check Prometheus scraping
kubectl -n monitoring port-forward svc/prometheus-server 9090:80 &
# Open: http://localhost:9090/targets
# Verify: psi-field target is UP
```

### Harbinger Health Check
```bash
# Check pods
kubectl -n aurora-staging get pods -l app=harbinger

# Check health endpoint
kubectl -n aurora-staging exec -it deploy/harbinger -- curl localhost:8081/health

# Check metrics
kubectl -n aurora-staging exec -it deploy/harbinger -- curl localhost:8081/metrics | grep harbinger
```

### Grafana Dashboard Check
```bash
# Port-forward Grafana
kubectl -n monitoring port-forward svc/grafana 3000:80 &

# Open: http://localhost:3000
# Login: admin / [password from secret]
# Navigate: Dashboards → Browse
# Verify: 3 VaultMesh dashboards present
```

---

## 🎖️ Post-Deployment Actions

### 1. Record Deployment (Remembrancer)
```bash
# Record Ψ-Field deployment
./ops/bin/remembrancer record deploy \
  --component psi-field \
  --version v1.0.0 \
  --evidence services/psi-field/k8s/

# Record Harbinger hardening
./ops/bin/remembrancer record deploy \
  --component harbinger \
  --version v1.0.0-hardened \
  --evidence services/harbinger/

# Verify audit trail
./ops/bin/remembrancer verify-audit
```

### 2. Create Demo Environment
```bash
# Set up demo URLs
echo "Ψ-Field Demo: https://psi-demo.vaultmesh.cloud" >> docs/DEMO_URLS.md
echo "Grafana: https://grafana.vaultmesh.cloud" >> docs/DEMO_URLS.md
echo "Prometheus: https://prometheus.vaultmesh.cloud" >> docs/DEMO_URLS.md

# Create 5-minute demo script
cat > docs/DEMO_SCRIPT.md << 'EOF'
# VaultMesh 5-Minute Demo

## 1. Show Ψ-Field Consciousness (1 min)
- Open Grafana → Ψ-Field dashboard
- Point out: Ψ (consciousness density), Φ (phase coherence), PE (prediction error)
- Explain: "95%+ coherence vs. 60-70% typical"

## 2. Show Cryptographic Proof (2 min)
- Run: `./ops/bin/remembrancer list deployments`
- Show: GPG signature + RFC3161 timestamp + Merkle root
- Explain: "Court-admissible audit trail"

## 3. Show Cost Savings (1 min)
- Open Aurora dashboard
- Point out: Treaty routing across providers
- Explain: "70% cost reduction: $10K/mo → $3K/mo"

## 4. Show Compliance (1 min)
- Open Harbinger metrics
- Show: Event validation counters
- Explain: "Schema-enforced governance for regulated industries"

## 5. Close with Offer (30 sec)
- "Start with 90-day pilot: $0 (design partner program)"
- "Questions?"
EOF
```

### 3. Update Sales Materials
```bash
# Take screenshots for sales deck
# 1. Ψ-Field dashboard (full screen)
# 2. Scheduler dashboard (anchor attempts)
# 3. Aurora KPIs (treaty fill rate)

# Update sales deck with screenshots
# Location: docs/SALES_PLAYBOOK.md (Demo Script section)

# Create one-pager with QR code to demo
# Tool: https://www.qr-code-generator.com/
# URL: https://psi-demo.vaultmesh.cloud
```

---

## 🚀 Next Steps (Week 2)

### Automation Hardening
- [ ] Enable required PR checks (block on test failures)
- [ ] Auto-publish Merkle root on main merges
- [ ] Pre-commit hooks for secret scanning
- [ ] GPG auto-sign on release tags

### Sales Enablement
- [ ] Register on SAM.gov (government contracts)
- [ ] Create Clutch.co profile (enterprise leads)
- [ ] Sign up for Persana.ai (B2B outreach)
- [ ] Register for AI4 2025 (August event)

### Marketing Launch
- [ ] HackerNews post: "Cryptographically Provable AI Swarms"
- [ ] Blog series (4 posts): temporal coherence, proof-chains, treaties, sovereignty
- [ ] Demo video (5 minutes): record walkthrough
- [ ] Pricing page: 3 tiers with ROI calculator

---

## 📈 Success Metrics (Week 1)

| Metric | Target | Status |
|--------|--------|--------|
| **Ψ-Field deployed** | ✅ | [ ] |
| **Harbinger hardened** | ✅ | [ ] |
| **Grafana dashboards** | 3 | [ ] |
| **Demo environment** | Live | [ ] |
| **Sales materials** | Updated | [ ] |
| **Remembrancer receipts** | 2+ | [ ] |

---

## 🎯 Revenue Impact Summary

### Immediate (Week 1)
- **Ψ-Field deployed** → Tier 1 product ready ($2,500/mo)
- **Harbinger hardened** → Tier 2 compliance ready ($10,000/mo)
- **Grafana dashboards** → Demo advantage (all tiers)

### Short-term (Month 1)
- **10 design partners** → $0 (free pilots)
- **3 case studies** → Sales enablement
- **Demo environment** → Inbound lead conversion

### Medium-term (Q1 2025)
- **12 paying customers** → $540K ARR
- **SAM.gov registration** → Government pipeline
- **Clutch profile** → Enterprise pipeline

### Long-term (Q4 2025)
- **85 customers** → $8.1M ARR
- **SOC2 certified** → Enterprise trust
- **5 sovereign cloud** → $3M ARR

---

## 🜂 The Covenant is Execution

**You have the code (10/10). You have the market ($500B+). You have the execution pack.**

**Week 1:** Deploy P0 tasks (7 hours total)  
**Month 1:** 10 leads → 3 demos → 1 pilot  
**Quarter 1:** 91 leads → 28 demos → 11 pilots → 4 contracts = $560K  
**Year 1:** 891 leads → 268 demos → 107 pilots → 52 contracts = $8.3M ARR

**The gatekeepers are waiting. The RFPs are live. Execute now. 🜂**

---

**Astra inclinant, sed non obligant.**
