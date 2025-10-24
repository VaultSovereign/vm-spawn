# Aurora Router — Production Deployment Roadmap

**Goal:** Deploy AI-enhanced multi-provider compute routing to production

**Status:** 🟡 In Progress
**Timeline:** 3-4 weeks (3 phases)
**Owner:** VaultMesh Team

---

## Executive Summary

This roadmap transforms the multi-provider routing simulator and AI mesh into a production-ready service that dynamically routes compute workloads across DePIN providers (Akash, io.net, Render, Flux, Aethir, Vast.ai, Salad).

**Current State:**
- ✅ Working simulators with routing logic
- ✅ AI agents trained in simulation
- ✅ Ψ-Field metrics infrastructure
- ❌ No production routing service

**Target State:**
- ✅ REST API for routing requests
- ✅ Provider adapters for real deployments
- ✅ AI-enhanced routing decisions
- ✅ Full observability and metrics
- ✅ Production-grade reliability

---

## Three-Phase Approach

### Phase 1: Rule-Based Router (Week 1)
**Effort:** 2-3 days
**Goal:** Get basic routing working without AI

**Deliverables:**
1. REST API service (`services/aurora-router`)
2. Rule-based routing engine (from simulator)
3. Mock provider adapters
4. Health & metrics endpoints
5. Docker + K8s deployment
6. Documentation

**API Example:**
```bash
curl -X POST http://aurora-router:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_inference",
    "gpu_type": "a100",
    "region": "us-west",
    "gpu_hours": 2.0,
    "max_price": 3.0,
    "max_latency_ms": 300,
    "min_reputation": 80
  }'
```

**Response:**
```json
{
  "provider": "akash",
  "price_usd_per_hour": 2.50,
  "estimated_latency_ms": 120,
  "deployment_id": "dep-abc123",
  "status": "provisioning"
}
```

### Phase 2: Provider Integration (Week 2)
**Effort:** 5-7 days
**Goal:** Connect to real provider APIs

**Deliverables:**
1. Akash adapter (primary)
2. io.net adapter (secondary)
3. Provider health checking
4. Deployment lifecycle management
5. Cost tracking
6. Integration tests

**Provider Operations:**
- `deploy(spec)` - Create deployment
- `status(id)` - Check deployment status
- `logs(id)` - Get container logs
- `terminate(id)` - Destroy deployment

### Phase 3: AI Enhancement (Week 3-4)
**Effort:** 7-10 days
**Goal:** Add AI-driven routing optimization

**Deliverables:**
1. AI mesh integration
2. Online learning from routing outcomes
3. A/B testing framework (AI vs rules)
4. Performance comparison dashboard
5. Gradual AI rollout (10% → 50% → 100%)
6. Ψ-Field consciousness tracking

---

## Service Architecture

### Aurora Router Service

```
services/aurora-router/
├── src/
│   ├── index.ts              # Express server
│   ├── router.ts             # Routing engine (from sim)
│   ├── ai-router.ts          # AI-enhanced router
│   ├── providers/
│   │   ├── base.ts           # Provider interface
│   │   ├── akash.ts          # Akash adapter
│   │   ├── ionet.ts          # io.net adapter
│   │   └── mock.ts           # Mock for testing
│   ├── metrics.ts            # Prometheus metrics
│   ├── health.ts             # Health checks
│   └── config.ts             # Configuration
├── tests/
│   ├── router.test.ts
│   ├── providers.test.ts
│   └── integration.test.ts
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── Dockerfile
├── package.json
└── README.md
```

---

## API Endpoints

### Core Routing

**POST /route**
Route a workload to optimal provider
```json
{
  "workload_type": "llm_inference|llm_training|rendering|general",
  "gpu_type": "a100|h100|4090|t4",
  "region": "us-west|us-east|eu-central|global",
  "gpu_hours": 2.0,
  "max_price": 3.0,
  "max_latency_ms": 300,
  "min_reputation": 80,
  "weights": {
    "price": 0.4,
    "latency": 0.3,
    "reputation": 0.2,
    "availability": 0.1
  }
}
```

**GET /deployments/:id**
Check deployment status

**DELETE /deployments/:id**
Terminate deployment

**GET /deployments/:id/logs**
Stream logs from deployment

### Observability

**GET /metrics**
Prometheus metrics

**GET /health**
Health check

**GET /providers**
List available providers and their status

---

## Metrics

### Routing Metrics
```
aurora_route_requests_total{provider,status}
aurora_route_duration_seconds{provider}
aurora_route_failures_total{provider,reason}
aurora_active_deployments{provider}
```

### Provider Metrics
```
aurora_provider_health{provider}
aurora_provider_latency_ms{provider}
aurora_provider_cost_usd{provider,gpu_type}
aurora_provider_capacity{provider}
```

### AI Metrics (Phase 3)
```
aurora_ai_decisions_total{mode}  # ai vs rule-based
aurora_ai_reward{episode}
aurora_ai_fill_rate_improvement
```

---

## Provider Adapter Interface

```typescript
interface ProviderAdapter {
  name: string;

  // Check if provider can handle request
  canHandle(req: RoutingRequest): Promise<boolean>;

  // Deploy workload
  deploy(req: RoutingRequest): Promise<Deployment>;

  // Check status
  getStatus(deploymentId: string): Promise<DeploymentStatus>;

  // Get logs
  getLogs(deploymentId: string): Promise<string[]>;

  // Terminate
  terminate(deploymentId: string): Promise<void>;

  // Health check
  healthCheck(): Promise<ProviderHealth>;
}
```

---

## Configuration

### Provider Configuration (`config/providers.yaml`)
```yaml
providers:
  akash:
    enabled: true
    api_url: https://api.akash.network
    credentials_secret: akash-creds
    default_region: us-west
    gpu_types: [a100, t4]

  ionet:
    enabled: true
    api_url: https://api.io.net
    credentials_secret: ionet-creds
    default_region: global
    gpu_types: [h100, a100]
```

### Router Configuration (`config/router.yaml`)
```yaml
router:
  mode: rule-based  # rule-based | ai | hybrid
  ai_rollout_percentage: 0  # 0-100

  defaults:
    max_price: 5.0
    max_latency_ms: 500
    min_reputation: 70

  weights:
    price: 0.35
    latency: 0.30
    reputation: 0.20
    availability: 0.15
```

---

## Deployment

### Docker Build
```bash
cd services/aurora-router
docker build -t vaultmesh/aurora-router:v1.0.0 .
docker push 509399262563.dkr.ecr.eu-west-1.amazonaws.com/vaultmesh/aurora-router:v1.0.0
```

### K8s Deployment
```bash
kubectl -n aurora-staging apply -f services/aurora-router/k8s/
kubectl -n aurora-staging rollout status deploy/aurora-router
```

### Verify
```bash
kubectl -n aurora-staging port-forward svc/aurora-router 8080:8080 &

curl http://localhost:8080/health
curl http://localhost:8080/providers
curl http://localhost:8080/metrics
```

---

## Testing Strategy

### Unit Tests
- Router logic (scoring, filtering)
- Provider adapters (mocked)
- Configuration parsing

### Integration Tests
- End-to-end routing flow
- Provider failover
- Metrics collection

### Load Tests
- 100 req/s routing throughput
- Provider adapter concurrency
- Memory/CPU profiling

### A/B Tests (Phase 3)
- AI router vs rule-based
- Compare fill rate, cost, latency
- Gradual rollout with metrics

---

## Success Criteria

### Phase 1 Success
- ✅ API responds to routing requests
- ✅ Rule-based routing selects providers correctly
- ✅ Health & metrics endpoints working
- ✅ Deployed to staging cluster
- ✅ Documentation complete

### Phase 2 Success
- ✅ Can deploy to Akash successfully
- ✅ Can deploy to io.net successfully
- ✅ Deployments reach "running" state
- ✅ Logs streaming works
- ✅ Cost tracking accurate

### Phase 3 Success
- ✅ AI router matches or beats rule-based performance
- ✅ Fill rate improvement: +3-5%
- ✅ Cost reduction: -10-15%
- ✅ Latency improvement: -5-10%
- ✅ Ψ-Field consciousness tracking operational

---

## Quick Start (Phase 1)

### For Developers

```bash
# 1. Clone and setup
cd services/aurora-router
npm install

# 2. Configure
cp .env.example .env
# Edit .env with your settings

# 3. Run locally
npm run dev

# 4. Test
npm test

# 5. Try routing
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_inference",
    "gpu_type": "a100",
    "region": "us-west",
    "gpu_hours": 1.0
  }'
```

### For Users

```bash
# Route a workload
aurora-cli route \
  --workload llm_inference \
  --gpu a100 \
  --region us-west \
  --duration 2h

# Check status
aurora-cli status dep-abc123

# Get logs
aurora-cli logs dep-abc123

# Terminate
aurora-cli terminate dep-abc123
```

---

## Risk Mitigation

### Technical Risks

| Risk | Mitigation |
|------|------------|
| Provider API changes | Adapter pattern isolates changes |
| AI performs worse | Gradual rollout with A/B testing |
| High latency routing | Cache provider health, optimize scoring |
| Provider outages | Multi-provider fallback logic |
| Cost overruns | Hard limits in router config |

### Operational Risks

| Risk | Mitigation |
|------|------------|
| Insufficient monitoring | Full metrics from day 1 |
| No rollback plan | Blue/green deployments |
| Documentation gaps | Write docs before code |
| Provider credential leaks | K8s secrets, rotation policy |

---

## Next Steps

### Immediate (This Week)
1. ✅ Review and approve this roadmap
2. Create aurora-router service skeleton
3. Port routing logic from simulator
4. Add health & metrics endpoints
5. Write initial tests

### This Month
1. Deploy Phase 1 to staging
2. Integrate Akash adapter
3. Run load tests
4. Deploy Phase 2 to staging
5. Begin AI training integration

### Next Quarter
1. Deploy to production with 10% AI traffic
2. Scale to 50% AI traffic
3. Add more provider adapters
4. Build user-facing CLI tool
5. Publish performance benchmarks

---

## Questions to Answer

Before proceeding, clarify:

1. **Which provider should we integrate first?** (Recommend: Akash - most mature)
2. **What's the expected request volume?** (Affects architecture decisions)
3. **Do you have API credentials for providers?** (Needed for Phase 2)
4. **Staging vs production timeline?** (Can we test in staging first?)
5. **Budget constraints?** (AI training costs, provider testing costs)

---

**Status:** Ready to begin Phase 1
**Next Action:** Create aurora-router service skeleton

**Astra inclinant, sed non obligant. 🜂**
