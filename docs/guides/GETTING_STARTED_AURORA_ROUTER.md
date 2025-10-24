# Getting Started with Aurora Router

**Welcome!** This guide will help you deploy and use Aurora Router to route compute workloads across multiple DePIN providers.

---

## What You Have Now

I've created a complete **Phase 1 production-ready routing service** for you:

```
✅ services/aurora-router/          # Production service
✅ PRODUCTION_ROUTER_ROADMAP.md    # Complete 3-phase roadmap
✅ Working REST API                 # /route, /health, /metrics
✅ Rule-based routing engine        # From simulator
✅ Prometheus metrics               # Full observability
✅ Docker + K8s manifests           # Ready to deploy
✅ Comprehensive documentation      # README + guides
```

---

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
cd services/aurora-router
npm install
```

### 2. Run Locally

```bash
npm run dev
```

You should see:
```
INFO: Aurora Router started {"port":8080,"mode":"rule-based","providers":4}
```

### 3. Test the API

Open a new terminal and try routing a workload:

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_inference",
    "gpu_type": "a100",
    "region": "us-west",
    "gpu_hours": 2.0
  }'
```

**Expected response:**
```json
{
  "provider": "akash",
  "price_usd_per_hour": 2.50,
  "estimated_latency_ms": 120,
  "status": "provisioning"
}
```

### 4. Check Available Providers

```bash
curl http://localhost:8080/providers
```

You'll see 4 mock providers: Akash, io.net, Render, Vast.ai

### 5. Check Metrics

```bash
curl http://localhost:8080/metrics
```

Prometheus metrics showing routing requests, latency, etc.

---

## How It Works

### Routing Flow

```
1. You send a request → POST /route
2. Router filters providers (region, GPU, price, latency, reputation)
3. Router scores viable providers (weighted utility function)
4. Router selects best provider and returns it
5. Metrics are recorded for observability
```

### Routing Algorithm

**Filter Phase:**
- Must support your region
- Must have your GPU type
- Must meet price constraint
- Must meet latency SLA
- Must meet reputation threshold
- Must have capacity

**Scoring Phase:**
```
score = (0.35 × 1/price) +
        (0.30 × 1/latency) +
        (0.20 × reputation/100) +
        (0.15 × capacity_available/capacity_total)
```

**Selection Phase:**
- Pick highest-scoring provider
- Allocate capacity
- Return routing decision

---

## Using the Router

### Basic Request

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_inference",
    "gpu_type": "a100",
    "region": "us-west",
    "gpu_hours": 2.0
  }'
```

### With Constraints

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_training",
    "gpu_type": "h100",
    "region": "global",
    "gpu_hours": 10.0,
    "max_price": 4.5,
    "max_latency_ms": 200,
    "min_reputation": 90
  }'
```

### Custom Weights (Optimize for Price)

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "rendering",
    "gpu_type": "4090",
    "region": "us-west",
    "gpu_hours": 1.0,
    "weights": {
      "price": 0.6,
      "latency": 0.2,
      "reputation": 0.1,
      "availability": 0.1
    }
  }'
```

---

## Deploy to Kubernetes

### 1. Build Docker Image

```bash
cd services/aurora-router

# Build
docker build -t aurora-router:v1.0.0 .

# Tag for ECR
docker tag aurora-router:v1.0.0 \
  509399262563.dkr.ecr.eu-west-1.amazonaws.com/vaultmesh/aurora-router:v1.0.0

# Push
docker push 509399262563.dkr.ecr.eu-west-1.amazonaws.com/vaultmesh/aurora-router:v1.0.0
```

### 2. Deploy to Cluster

```bash
kubectl -n aurora-staging apply -f k8s/
```

This creates:
- Deployment (2 replicas)
- Service (ClusterIP)
- ServiceMonitor (Prometheus scraping)

### 3. Verify Deployment

```bash
# Check pods
kubectl -n aurora-staging get pods -l app=aurora-router

# Check service
kubectl -n aurora-staging get svc aurora-router

# Port forward to test
kubectl -n aurora-staging port-forward svc/aurora-router 8080:8080 &

# Test
curl http://localhost:8080/health
```

### 4. Check Metrics in Prometheus

```bash
# Port forward to Prometheus
kubectl -n aurora-staging port-forward svc/prometheus-server 9090:80 &

# Query metrics
curl -s 'http://localhost:9090/api/v1/query?query=aurora_route_requests_total' | jq
```

---

## What's Next: Phase 2 & 3

### Phase 2: Real Provider Integration (Next Week)

**Goal:** Connect to actual Akash and io.net APIs

**What you need:**
1. Akash API credentials
2. io.net API credentials
3. Provider SDK documentation

**I'll build:**
- Provider adapter interface
- Akash adapter (deploy, status, logs, terminate)
- io.net adapter
- Real deployment tracking
- Cost monitoring

### Phase 3: AI Enhancement (Weeks 3-4)

**Goal:** Add AI-driven routing optimization

**Features:**
- Q-learning agents for provider selection
- Online learning from routing outcomes
- A/B testing (AI vs rules)
- Ψ-Field consciousness tracking
- Gradual rollout (10% → 50% → 100%)

---

## Understanding the Codebase

### Key Files

```
services/aurora-router/src/
├── index.ts       # Express server, API endpoints
├── router.ts      # Routing algorithm (filter → score → select)
├── config.ts      # Configuration & request/response schemas
├── metrics.ts     # Prometheus metrics definitions
├── health.ts      # Health check logic
└── logger.ts      # Structured logging
```

### Key Concepts

**ProviderState:** Data structure for each provider
- ID, name, regions, GPU types
- Pricing, latency, reputation
- Capacity tracking

**RoutingRequest:** Your API request
- Workload type, GPU type, region
- Constraints (price, latency, reputation)
- Weights for scoring

**RoutingResponse:** Router's decision
- Selected provider
- Price and latency
- Deployment status

---

## Monitoring & Observability

### Key Metrics

```promql
# Total routing requests
aurora_route_requests_total{provider="akash",status="provisioning"}

# Routing decision latency
aurora_route_duration_seconds{provider="akash",mode="rule-based"}

# Failed routing attempts
aurora_route_failures_total{provider="akash",reason="no_capacity"}

# Provider health
aurora_provider_health{provider="akash"}
```

### Grafana Dashboard (Coming Soon)

I can create a Grafana dashboard with:
- Request rate over time
- Provider selection distribution
- Average routing latency
- Failure rate by reason
- Provider health status

---

## Testing

### Run Tests

```bash
cd services/aurora-router
npm test
```

### Test Different Scenarios

**High price sensitivity:**
```bash
curl -X POST http://localhost:8080/route \
  -d '{"workload_type":"llm_inference","gpu_type":"a100","region":"global","gpu_hours":1,"weights":{"price":0.7,"latency":0.1,"reputation":0.1,"availability":0.1}}'
```

**Low latency required:**
```bash
curl -X POST http://localhost:8080/route \
  -d '{"workload_type":"llm_inference","gpu_type":"a100","region":"us-west","gpu_hours":1,"max_latency_ms":150}'
```

**High reputation only:**
```bash
curl -X POST http://localhost:8080/route \
  -d '{"workload_type":"llm_training","gpu_type":"h100","region":"global","gpu_hours":5,"min_reputation":95}'
```

---

## Common Questions

### Q: Is this using AI yet?
**A:** No, Phase 1 uses rule-based routing (same logic as simulator). AI comes in Phase 3.

### Q: Can it deploy real workloads?
**A:** Not yet. Phase 1 uses mock providers. Phase 2 adds real Akash/io.net integration.

### Q: How do I add a new provider?
**A:** Edit the `MOCK_PROVIDERS` array in `src/index.ts`. In Phase 2, you'll configure via YAML.

### Q: What happens when no provider matches?
**A:** Returns `status: "no_capacity"` with `reason` explaining why.

### Q: How is capacity tracked?
**A:** Each provider has `capacity_gpu_hours_per_step` that decreases with each allocation. Resets every 60 seconds.

---

## Troubleshooting

### "No viable providers"
- Check your constraints (max_price, max_latency_ms, min_reputation)
- Try with fewer constraints or `region: "global"`
- Check provider capacity hasn't been exhausted

### Port 8080 already in use
```bash
PORT=8081 npm run dev
```

### Can't connect to Prometheus
```bash
# Check if port-forward is running
ps aux | grep port-forward

# Restart it
kubectl -n aurora-staging port-forward svc/prometheus-server 9090:80 &
```

---

## Next Actions

### Immediate (Today)
1. ✅ Run locally and test the API
2. ✅ Understand the routing algorithm
3. ✅ Review the roadmap: `PRODUCTION_ROUTER_ROADMAP.md`

### This Week
1. Deploy to staging cluster
2. Add Grafana dashboard
3. Obtain Akash API credentials
4. Start Phase 2 planning

### Questions to Answer
1. **Which provider should we integrate first?** (I recommend Akash)
2. **What's your expected request volume?** (affects scaling)
3. **Do you have provider API credentials?** (needed for Phase 2)
4. **When do you want AI routing?** (Phase 3 timeline)

---

## Resources

- **Roadmap:** `PRODUCTION_ROUTER_ROADMAP.md`
- **Service README:** `services/aurora-router/README.md`
- **Simulator:** `sim/multi-provider-routing-simulator/`
- **AI Mesh:** `sim/ai-mesh/`
- **Ψ-Field:** `services/psi-field/`

---

## Summary

**What you have:**
- ✅ Production-ready routing service
- ✅ Working REST API
- ✅ Full observability
- ✅ K8s deployment ready

**What's next:**
- ⏳ Phase 2: Real provider integration
- ⏳ Phase 3: AI enhancement
- ⏳ Production deployment

**To get started:**
```bash
cd services/aurora-router
npm install
npm run dev
```

Then test with:
```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{"workload_type":"llm_inference","gpu_type":"a100","region":"us-west","gpu_hours":2.0}'
```

---

**Status:** Phase 1 Complete ✅
**Questions?** Check `PRODUCTION_ROUTER_ROADMAP.md` or ask me!

**Astra inclinant, sed non obligant. 🜂**
