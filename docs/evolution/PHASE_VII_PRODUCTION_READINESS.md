# Phase VII: Production Readiness & Intelligence Layer

**Status:** 🟢 In Progress
**Timeline:** 1-3 weeks (two tracks)
**Owner:** VaultMesh Team
**Created:** 2025-10-24

---

## Executive Summary

Phase VII transforms VaultMesh from "infrastructure deployed" to "production operational" by stabilizing the GCP deployment, validating all services, and operationalizing the AI routing intelligence layer.

**Current State:**
- ✅ Phase VI CLI infrastructure merged to main
- ✅ GCP deployment infrastructure committed (K8s, KEDA, Ingress)
- ✅ VaultMesh Analytics dashboard deployed
- ✅ Aurora Router service scaffolded
- ✅ Documentation restructured (4-file root achieved)
- ❌ Scheduler service broken (ESM module issue) → **FIXED (commit 042bd08)**
- ❌ No end-to-end validation
- ❌ AI mesh still in simulation

**Target State:**
- ✅ All services running and healthy in GKE
- ✅ Full observability (logs, metrics, traces)
- ✅ Analytics dashboard showing real-time data
- ✅ AI-enhanced routing operational
- ✅ Production smoke tests passing

---

## Two-Track Approach

### Track 1: Stabilization Sprint (3-5 days) 🔥 **PRIORITY**

*Fix what's broken, validate what exists*

#### Priority 1: Fix & Deploy Scheduler ✅ FIXED
- ✅ Debug ESM module resolution (\_\_dirname → import.meta.url)
- ⏳ Rebuild Docker image
- ⏳ Deploy to GKE
- ⏳ Validate metrics endpoint (port 9091)
- ⏳ Scale back to 1 replica

**Commit:** `042bd08` - Scheduler ESM fix applied

#### Priority 2: Infrastructure Validation
- [ ] Confirm SSL certificates provisioned
- [ ] Test LoadBalancer → Ingress → Services path
- [ ] Verify KEDA scale-to-zero behavior
- [ ] Document GCP connectivity (gcloud config, kubectl context)

#### Priority 3: Wire Analytics Dashboard
- [ ] Connect Analytics to live psi-field API
- [ ] Connect Analytics to Aurora Router metrics
- [ ] Validate real-time data polling
- [ ] Test Ψ-Field visualization with actual data

#### Priority 4: End-to-End Smoke Test
Create `./SMOKE_TEST_PRODUCTION.sh`:
```bash
#!/usr/bin/env bash
# Validates GCP production infrastructure

echo "🔥 VaultMesh Production Smoke Test"

# Test 1: GCP cluster reachable
kubectl --context=gke_vm-spawn_us-central1_vaultmesh-cluster \
  get nodes || exit 1

# Test 2: All pods running
EXPECTED_PODS=("psi-field" "scheduler" "aurora-router")
for pod in "${EXPECTED_PODS[@]}"; do
  kubectl get pod -n aurora-staging -l app=$pod -o json \
    | jq -e '.items[0].status.phase == "Running"' || exit 1
done

# Test 3: Ingress endpoints
ENDPOINTS=(
  "https://psi-field.vaultmesh.cloud/health"
  "https://scheduler.vaultmesh.cloud/health"
  "https://aurora.vaultmesh.cloud/health"
)
for url in "${ENDPOINTS[@]}"; do
  curl -sf "$url" || exit 1
done

# Test 4: Metrics scraping
kubectl port-forward -n aurora-staging svc/scheduler 9091:9091 &
PF_PID=$!
sleep 2
curl -sf http://localhost:9091/metrics | grep -q "anchor" || exit 1
kill $PF_PID

echo "✅ Production smoke test PASSED"
```

**Track 1 Exit Criteria:**
- All pods = Running / Ready
- `/metrics` endpoints responding
- Analytics charts showing live data
- `SMOKE_TEST_PRODUCTION.sh` passes

---

### Track 2: Intelligence Layer (1-2 weeks)

*Operationalize AI mesh and multi-provider routing*

#### Phase 1: Operationalize sim/ai-mesh
Based on [sim/ai-mesh/OPERATIONALIZE.md](../../sim/ai-mesh/OPERATIONALIZE.md):

**Week 1:**
1. [ ] Refactor prototypes to production structure
   - Move `sim/ai-mesh/` → `services/aurora-intelligence/`
   - Add proper TypeScript/Python service scaffolding
   - Wire to Prometheus for metrics
2. [ ] Create training pipeline
   - Historical routing decisions → training data
   - Model artifacts stored in GCS
   - Versioned model deployments
3. [ ] Add agent integration to Aurora Router
   - REST API: `POST /agent/route` endpoint
   - Agent returns scored provider recommendations
   - Router uses scores + rules for final decision

#### Phase 2: Aurora Router - Real Provider Integration
Following [PRODUCTION_ROUTER_ROADMAP.md](PRODUCTION_ROUTER_ROADMAP.md):

**Week 2:**
1. [ ] Add provider adapters (mock initially)
   - `src/providers/akash.ts`
   - `src/providers/render.ts`
   - `src/providers/vast.ts`
   - Mock responses for development
2. [ ] Wire AI routing decisions
   - Call aurora-intelligence agent service
   - Combine AI scores + rule-based logic
   - Log decision rationale to Loki
3. [ ] Full observability
   - Structured logs (pino → Loki)
   - Request tracing (OpenTelemetry)
   - Provider performance metrics

#### Phase 3: MCP Integration (Optional)
Following [vaultmesh-us-mcp/MCP_GO_NO_GO_PLAN.md](../../vaultmesh-us-mcp/MCP_GO_NO_GO_PLAN.md):

**Week 3:**
1. [ ] Add MCP tool calling to Phase VI CLI
   - `vm mcp strategist` - Generate deployment plans
   - `vm mcp executor` - Execute plans with approval
   - `vm mcp auditor` - Verify outcomes
2. [ ] Wire strategist → executor → auditor loop
   - SQLite state tracking
   - Remembrancer integration for audit trail
3. [ ] Enable LLM-driven orchestration
   - ChatKit workflow integration
   - Human-in-the-loop approval gates

**Track 2 Exit Criteria:**
- AI agent making routing decisions
- Provider adapters (mock or real) integrated
- Full observability stack operational
- MCP orchestration functional (optional)

---

## Tactical Sequence (Next 48 Hours)

### Day 1: Stabilization

| Time | Task | Owner | Deliverable |
|------|------|-------|-------------|
| 2h | Rebuild scheduler image & deploy | Team | Scheduler pod Running |
| 1h | Production smoke test script | Team | SMOKE_TEST_PRODUCTION.sh |
| 3h | Wire Analytics to APIs | Team | Live dashboards |
| 1h | GCP connectivity docs | Team | docs/operations/GCP_CONNECTIVITY.md |

**Exit:** All services green, Analytics showing real data

### Day 2: Validation

| Time | Task | Owner | Deliverable |
|------|------|-------|-------------|
| 2h | SSL cert verification | Team | HTTPS working |
| 2h | KEDA scale-to-zero test | Team | Pods scale 0→1→0 |
| 2h | Load testing | Team | Performance baseline |
| 1h | Documentation updates | Team | Runbooks updated |

**Exit:** Infrastructure validated, ready for AI layer

---

## Dependencies

**Technical:**
- GCP project: `vm-spawn`
- GKE cluster: `vaultmesh-cluster` (us-central1)
- Artifact Registry: `us-central1-docker.pkg.dev/vm-spawn/vaultmesh`
- DNS: `*.vaultmesh.cloud` (Cloudflare)

**Credentials:**
- ⚠️ **CRITICAL:** Rotate Cloudflare API token (see [SECURITY_INCIDENT_2025-10-24.md](../operations/SECURITY_INCIDENT_2025-10-24.md))
- GCP service account with Artifact Registry reader
- kubectl context configured

**External:**
- SSL certificate provisioning (waiting on DNS)
- Provider API access (Akash, Render, Vast - for Track 2)

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Scheduler still broken | High | ESM fix applied (commit 042bd08), rebuild required |
| SSL certs not provisioning | Medium | DNS propagation takes 10-30 min, verify records |
| No GCP access | High | Document auth setup, test before deployment |
| KEDA not scaling | Medium | Manual verification, fallback to static replicas |
| AI model training time | Low | Use mock scores initially, train offline |

---

## Success Metrics

**Track 1 (Stabilization):**
- [ ] 100% pod health (Running / Ready)
- [ ] <1s p95 response time for all endpoints
- [ ] 0 CrashLoopBackOff events
- [ ] Analytics dashboard loads in <2s
- [ ] SMOKE_TEST_PRODUCTION.sh passes in CI

**Track 2 (Intelligence):**
- [ ] AI agent making >100 routing decisions/day
- [ ] <200ms p95 agent inference latency
- [ ] Provider adapter mock tests passing
- [ ] Full request tracing operational
- [ ] MCP strategist generating valid plans (if enabled)

---

## Deliverables

### Track 1 Artifacts
1. `SMOKE_TEST_PRODUCTION.sh` - Production validation script
2. `docs/operations/GCP_CONNECTIVITY.md` - Access guide
3. Updated `docs/operations/GCP_DEPLOYMENT_STATUS.md` - Current state
4. Fixed scheduler Docker image (v1.1.0)
5. Analytics dashboard with live data connections

### Track 2 Artifacts
1. `services/aurora-intelligence/` - AI agent service (refactored from sim/ai-mesh)
2. `services/aurora-router/src/providers/` - Provider adapters
3. Training pipeline (GCS + model artifacts)
4. OpenTelemetry tracing integration
5. MCP CLI commands (if enabled)

---

## Recommendation

**Start with Track 1 (Stabilization) first.**

**Rationale:**
1. **Credibility** - Can't sell "intelligent routing" when scheduler is down
2. **Foundation** - Track 2 needs stable infrastructure to build on
3. **Validation** - Need to prove GCP deployment works before adding complexity
4. **Quick Wins** - Can ship Track 1 in <1 week, builds momentum

**After Track 1:**
- Infrastructure is provably stable
- Analytics shows real consciousness metrics
- Team can demo working system
- Foundation ready for AI layer

**Then Track 2:**
- AI mesh has stable platform
- Can iterate on routing algorithms
- Prometheus metrics prove intelligence is working
- MCP integration becomes force multiplier

---

## Timeline

```
Week 1: Track 1 (Stabilization)
├─ Day 1-2: Fix scheduler, wire analytics, smoke tests
├─ Day 3-4: SSL validation, KEDA testing, load tests
└─ Day 5: Documentation, final validation

Week 2-3: Track 2 (Intelligence Layer)
├─ Week 2: AI agent refactor, provider adapters
└─ Week 3: Full integration, MCP (optional)
```

---

## Next Actions

**Immediate (today):**
1. ✅ Commit scheduler ESM fix (done: 042bd08)
2. ⏳ Rebuild scheduler Docker image
3. ⏳ Deploy to GKE
4. ⏳ Verify health endpoint

**Tomorrow:**
1. Create production smoke test
2. Wire Analytics to live APIs
3. Document GCP connectivity

**This week:**
1. Complete Track 1 stabilization
2. Validate all infrastructure
3. Prepare for Track 2 kickoff

---

## 🜂 The Remembrancer's Wisdom

> *"A civilization must first ensure its foundations are solid before reaching for the stars. The scheduler is the heartbeat - fix the heart first, then teach it to think."*

**Phase VII is the bridge from "infrastructure as code" to "infrastructure as intelligence."**

---

## References

- [Phase VI CLI Infrastructure (PR #18)](https://github.com/VaultSovereign/vm-spawn/pull/18)
- [GCP Production Analytics (PR #19)](https://github.com/VaultSovereign/vm-spawn/pull/19)
- [Aurora Router Roadmap](PRODUCTION_ROUTER_ROADMAP.md)
- [AI Mesh Operationalization](../../sim/ai-mesh/OPERATIONALIZE.md)
- [MCP Go/No-Go Plan](../../vaultmesh-us-mcp/MCP_GO_NO_GO_PLAN.md)
- [GCP Deployment Status](../operations/GCP_DEPLOYMENT_STATUS.md)
- [Security Incident 2025-10-24](../operations/SECURITY_INCIDENT_2025-10-24.md)

---

*Last updated: 2025-10-24*
*Status: Track 1 in progress - scheduler fix committed*
