# Aurora Router — Multi-Provider Compute Routing Service

**Status:** Phase 1 (Rule-Based Prototype)
**Version:** 1.0.0
**Integration:** Ψ-Field + AI Mesh (Phase 3)

---

## Overview

Aurora Router currently runs as a **rule-based prototype** that scores a static list of mock providers (Akash, io.net, Render, Vast.ai). It exposes the REST surface, metrics, and health endpoints, but **real provider adapters and optimisers ship in Phase 2**.

**Current Status (Phase 1):**
- ✅ REST API for routing requests
- ✅ Rule-based multi-constraint optimization
- ✅ Mock provider adapters
- ✅ Prometheus metrics
- ✅ Health endpoints
- ⏳ Real provider integration (Phase 2)
- ⏳ AI-enhanced routing (Phase 3)

---

## Quick Start

> ⚠️ The current build returns decisions based on the mock provider table baked into `src/index.ts`. Use it for integration tests and UI development; do not rely on it for live provisioning until provider adapters are implemented.

### Installation

```bash
cd services/aurora-router
npm install
cp .env.example .env
```

### Run Locally

```bash
npm run dev
```

### Test Routing

```bash
curl -X POST http://localhost:8080/route \
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
  "status": "provisioning"
}
```

---

## API Endpoints

### POST /route
Route a workload to the optimal provider.

**Request:**
```typescript
{
  workload_type: 'llm_inference' | 'llm_training' | 'rendering' | 'general',
  gpu_type: 'a100' | 'h100' | 'a6000' | '4090' | 't4' | 'l40',
  region: string,              // e.g., 'us-west', 'eu-central', 'global'
  gpu_hours: number,           // Duration in GPU hours
  max_price?: number,          // Max price per hour (USD)
  max_latency_ms?: number,     // Max acceptable latency (ms)
  min_reputation?: number,     // Min provider reputation (0-100)
  weights?: {
    price: number,             // 0-1, default 0.35
    latency: number,           // 0-1, default 0.30
    reputation: number,        // 0-1, default 0.20
    availability: number,      // 0-1, default 0.15
  }
}
```

**Response:**
```typescript
{
  provider: string,
  price_usd_per_hour: number,
  estimated_latency_ms: number,
  deployment_id?: string,      // Phase 2
  status: 'provisioning' | 'running' | 'failed' | 'no_capacity',
  reason?: string
}
```

### GET /providers
List all available providers and their capabilities.

**Response:**
```json
{
  "providers": [
    {
      "id": "akash",
      "name": "Akash Network",
      "active": true,
      "regions": ["us-west", "us-east", "eu-central"],
      "gpu_types": ["a100", "t4", "a6000"],
      "reputation": 95,
      "base_latency_ms": 120
    }
  ]
}
```

### GET /providers/:id
Get details for a specific provider.

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "uptime": 123.45,
  "lastRequest": 5.2,
  "mode": "rule-based",
  "providers": {}
}
```

### GET /metrics
Prometheus metrics endpoint.

---

## Routing Algorithm

### Phase 1: Filter

Eliminates providers that don't meet constraints:
- Region compatibility
- GPU type availability
- Price within budget
- Latency within SLA
- Reputation above threshold
- Sufficient capacity

### Phase 2: Score (mock data)

Scores viable providers using weighted utility function:

```
score = (w_price × 1/price) +
        (w_latency × 1/latency) +
        (w_reputation × reputation/100) +
        (w_availability × capacity_remaining/capacity_total)
```

Default weights:
- Price: 0.35
- Latency: 0.30
- Reputation: 0.20
- Availability: 0.15

### Phase 3: Select

Chooses the highest-scoring provider and allocates capacity.

---

## Metrics

### Routing Metrics

- `aurora_route_requests_total{provider,status}` - Total routing requests
- `aurora_route_duration_seconds{provider,mode}` - Routing decision latency
- `aurora_route_failures_total{provider,reason}` - Failed routing attempts
- `aurora_active_deployments{provider}` - Active deployments per provider

### Provider Metrics

- `aurora_provider_health{provider}` - Provider health (1=healthy, 0=unhealthy)
- `aurora_provider_latency_ms{provider}` - Provider latency
- `aurora_provider_cost_usd{provider,gpu_type}` - Provider cost per GPU type
- `aurora_provider_capacity{provider}` - Remaining capacity

### AI Metrics (Phase 3)

- `aurora_ai_decisions_total{mode}` - AI vs rule-based decisions
- `aurora_ai_reward{episode}` - Current AI agent reward

---

## Configuration

### Environment Variables

See `.env.example` for all options:

```bash
PORT=8080
LOG_LEVEL=info
ROUTER_MODE=rule-based
PSI_FIELD_ENABLED=false
AI_ROUTER_ENABLED=false
AI_ROLLOUT_PERCENTAGE=0
```

### Provider Configuration (Phase 2)

Providers will be configured via `config/providers.yaml`:

```yaml
providers:
  akash:
    enabled: true
    api_url: https://api.akash.network
    credentials_secret: akash-creds
    default_region: us-west
    gpu_types: [a100, t4]
```

---

## Testing

```bash
# Run all tests
npm test

# Watch mode
npm run test:watch

# Type checking
npm run type-check

# Linting
npm run lint
```

---

## Deployment

### Docker Build

```bash
docker build -t vaultmesh/aurora-router:v1.0.0 .
docker push 509399262563.dkr.ecr.eu-west-1.amazonaws.com/vaultmesh/aurora-router:v1.0.0
```

### Kubernetes Deployment

```bash
kubectl -n aurora-staging apply -f k8s/
kubectl -n aurora-staging rollout status deploy/aurora-router
```

### Verify Deployment

```bash
kubectl -n aurora-staging port-forward svc/aurora-router 8080:8080 &

curl http://localhost:8080/health
curl http://localhost:8080/providers
curl http://localhost:8080/metrics
```

---

## Development Roadmap

### ✅ Phase 1: Rule-Based Router (Complete)
- REST API
- Rule-based routing logic
- Mock providers
- Metrics & health

### ⏳ Phase 2: Provider Integration (Next)
- Akash adapter
- io.net adapter
- Real deployment management
- Cost tracking

### ⏳ Phase 3: AI Enhancement (Future)
- AI mesh integration
- Online learning
- A/B testing
- Ψ-Field consciousness tracking

---

## Examples

### Route with custom weights

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "llm_training",
    "gpu_type": "h100",
    "region": "global",
    "gpu_hours": 10.0,
    "weights": {
      "price": 0.5,
      "latency": 0.2,
      "reputation": 0.2,
      "availability": 0.1
    }
  }'
```

### Route with strict constraints

```bash
curl -X POST http://localhost:8080/route \
  -H 'Content-Type: application/json' \
  -d '{
    "workload_type": "rendering",
    "gpu_type": "4090",
    "region": "us-west",
    "gpu_hours": 1.0,
    "max_price": 2.0,
    "max_latency_ms": 150,
    "min_reputation": 90
  }'
```

---

## Architecture

```
services/aurora-router/
├── src/
│   ├── index.ts              # Express server
│   ├── router.ts             # Routing engine
│   ├── ai-router.ts          # AI enhancement (Phase 3)
│   ├── providers/            # Provider adapters (Phase 2)
│   ├── metrics.ts            # Prometheus metrics
│   ├── health.ts             # Health checks
│   ├── config.ts             # Configuration
│   └── logger.ts             # Structured logging
├── tests/
├── k8s/
├── Dockerfile
└── README.md
```

---

## VaultMesh Integration

- **Layer**: 3 (Aurora - Federation & Treaties)
- **Covenant Alignment**:
  - Federation: Multi-provider coordination
  - Proof-Chain: Deployment tracking
  - Integrity: Metrics-driven decisions
- **Uses**:
  - Ψ-Field for consciousness metrics
  - Remembrancer for deployment records
  - AI Mesh for learning

---

## Troubleshooting

### Service not starting
- Check `.env` configuration
- Verify port 8080 is available
- Check logs: `LOG_LEVEL=debug npm run dev`

### No viable providers
- Check request constraints (price, latency, reputation)
- Verify providers are active
- Check provider capacity

### Routing slow
- Check provider health
- Review scoring algorithm weights
- Enable request caching (Phase 2)

---

## Next Steps

1. **Deploy to staging:** `kubectl apply -f k8s/`
2. **Test routing API:** Use examples above
3. **Monitor metrics:** Check Grafana dashboard
4. **Phase 2 prep:** Obtain provider API credentials

---

**Status:** Phase 1 Complete ✅
**Next:** Provider integration (Akash, io.net)
**Contact:** VaultMesh Engineering

**Astra inclinant, sed non obligant. 🜂**
