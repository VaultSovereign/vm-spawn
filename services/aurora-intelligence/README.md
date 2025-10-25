# Aurora Intelligence

AI-enhanced routing control plane using Q-learning for multi-provider decisions.

## Overview

Aurora Intelligence implements the Strategist/Executor/Auditor triad pattern:
- **Strategist**: Q-learning agent with Ψ-field context awareness
- **Executor**: Routes via Aurora Router service
- **Auditor**: Computes rewards and updates Q-table from feedback

## Features

- **Q-Learning**: Tabular Q-learning with epsilon-greedy exploration
- **Ψ-Field Integration**: Consciousness metrics inform state representation
- **Decision Tracing**: SQLite store for observability and debugging
- **Feedback Loop**: Closes the loop with reward computation and Q-updates
- **Prometheus Metrics**: Full telemetry for decisions, rewards, and cache performance

## Architecture

```
┌─────────────────────────────────────┐
│  POST /decisions                    │
│  (task_id, context, candidates)     │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Strategist (Q-Learning)            │
│  - Fetch Ψ-field metrics (cached)   │
│  - Featurize state                  │
│  - Select action (ε-greedy)         │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Executor                           │
│  - Call Aurora Router /route        │
│  - Get execution score              │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Store Trace                        │
│  (trace_id → state, action, chosen) │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Response                           │
│  (chosen, score, trace_id)          │
└─────────────────────────────────────┘

Later:
┌─────────────────────────────────────┐
│  POST /feedback                     │
│  (trace_id, outcome)                │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Auditor                            │
│  - Compute reward from outcome      │
│  - Update Q(state, action)          │
│  - Persist feedback                 │
└─────────────────────────────────────┘
```

## API

### POST /decisions

Make AI-enhanced routing decision.

**Request:**
```json
{
  "task_id": "task-123",
  "context": {
    "cpu": 8,
    "memory_gb": 32,
    "latency_ms": 50,
    "region": "us-west"
  },
  "candidates": [
    {"provider": "akash", "sku": "A8"},
    {"provider": "vast", "sku": "V4"}
  ]
}
```

**Response:**
```json
{
  "task_id": "task-123",
  "chosen": {"provider": "akash", "sku": "A8"},
  "score": 0.87,
  "trace_id": "tr_a1b2c3d4e5f6",
  "explanations": {
    "q_value": 0.74,
    "psi_coherence": 0.68,
    "psi_density": 0.82,
    "exploration": "exploit"
  }
}
```

### POST /feedback

Provide feedback to close learning loop.

**Request:**
```json
{
  "trace_id": "tr_a1b2c3d4e5f6",
  "outcome": {
    "latency_ms": 42,
    "cost": 0.12,
    "failures": 0,
    "slo_hit": true
  }
}
```

**Response:**
```json
{
  "updated": true,
  "reward": 0.85,
  "explanation": {
    "total_reward": 0.85,
    "components": {
      "latency_score": 0.79,
      "cost_score": 0.88,
      "slo_hit": true,
      "failures": 0
    },
    "explanation": "Excellent outcome: low latency, low cost, SLO met"
  },
  "q_updates": 142
}
```

### GET /status

Service status and model metrics.

**Response:**
```json
{
  "uptime_seconds": 3600,
  "model": {
    "episodes": 0,
    "updates": 142,
    "epsilon": 0.1,
    "alpha": 0.2,
    "gamma": 0.92,
    "q_table_size": 87,
    "total_state_action_pairs": 234
  },
  "cache": {
    "cache_hits": 450,
    "cache_misses": 123,
    "cache_errors": 2,
    "cache_hit_rate": 0.785,
    "cache_age_seconds": 2.3,
    "cache_valid": true,
    "cache_ttl": 5
  },
  "healthy": true
}
```

### GET /healthz

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1729876543.21
}
```

### GET /metrics

Prometheus metrics endpoint (text format).

## Local Development

```bash
cd services/aurora-intelligence

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # or `.venv\Scripts\activate` on Windows

# Install dependencies
pip install -r requirements.txt

# Set environment variables (optional)
export PSI_URL="http://localhost:8000"
export AURORA_ROUTER_URL="http://localhost:8080"

# Run service
uvicorn app.main:app --reload --port 8080
```

Visit http://localhost:8080/docs for interactive API documentation.

## Docker

```bash
cd services/aurora-intelligence

# Build
docker build -t aurora-intelligence:0.1.0 .

# Run
docker run -p 8080:8080 \
  -e PSI_URL=http://psi-field:8000 \
  -e AURORA_ROUTER_URL=http://aurora-router:8080 \
  aurora-intelligence:0.1.0
```

## Kubernetes Deployment

```bash
# Build and push image
docker build -t us-central1-docker.pkg.dev/vm-spawn/vaultmesh/aurora-intelligence:0.1.0 .
docker push us-central1-docker.pkg.dev/vm-spawn/vaultmesh/aurora-intelligence:0.1.0

# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# Verify
kubectl get pods -n vaultmesh -l app=aurora-intelligence
kubectl logs -n vaultmesh -l app=aurora-intelligence --tail=50
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `AURORA_ROUTER_URL` | `http://aurora-router:8080` | Aurora Router service URL |
| `PSI_URL` | `http://psi-field:8000` | Ψ-field service URL |
| `STORE_FILE` | `/data/decisions.db` | SQLite database path |
| `EPSILON` | `0.1` | Exploration rate (0-1) |
| `GAMMA` | `0.92` | Discount factor (0-1) |
| `ALPHA` | `0.2` | Learning rate (0-1) |
| `CACHE_TTL_S` | `5` | Ψ-field cache TTL (seconds) |
| `PORT` | `8080` | Service port |

## Testing

```bash
# Port-forward for local testing
kubectl port-forward -n vaultmesh svc/aurora-intelligence 8080:8080 &

# Check status
curl -s http://localhost:8080/status | jq

# Make decision
curl -s -X POST http://localhost:8080/decisions \
  -H 'Content-Type: application/json' \
  -d '{
    "task_id": "test-1",
    "context": {"cpu": 8, "latency_ms": 60, "region": "us-west"},
    "candidates": [
      {"provider": "akash", "sku": "A8"},
      {"provider": "vast", "sku": "V4"}
    ]
  }' | jq

# Provide feedback (use trace_id from above)
curl -s -X POST http://localhost:8080/feedback \
  -H 'Content-Type: application/json' \
  -d '{
    "trace_id": "tr_xxx",
    "outcome": {
      "latency_ms": 42,
      "cost": 0.12,
      "slo_hit": true
    }
  }' | jq

# Check metrics
curl -s http://localhost:8080/metrics | grep aurora_intelligence
```

## Metrics

Prometheus metrics exported at `/metrics`:

- `aurora_intelligence_decisions_total` - Total decisions (by provider, exploration)
- `aurora_intelligence_decision_latency_seconds` - Decision latency (by phase)
- `aurora_intelligence_q_updates_total` - Total Q-table updates
- `aurora_intelligence_rewards` - Observed rewards histogram
- `aurora_intelligence_epsilon` - Current exploration rate
- `aurora_intelligence_q_table_size` - Q-table state-action pairs
- `aurora_intelligence_psi_cache_hits_total` - Ψ-field cache hits
- `aurora_intelligence_psi_cache_misses_total` - Ψ-field cache misses
- `aurora_intelligence_feedback_total` - Feedback received (by outcome)
- `aurora_intelligence_trace_store_size` - Decision traces stored

## Next Steps

1. **Aurora Router Deployment** - Deploy Aurora Router service first
2. **Persistent Storage** - Replace emptyDir with PVC for production
3. **Epsilon Decay** - Add automatic exploration rate decay
4. **Q-Table Checkpointing** - Periodic saves to persistent storage
5. **Advanced Features**:
   - Multi-objective rewards (Pareto optimization)
   - Function approximation (neural Q-learning)
   - Experience replay buffer
   - Federated Q-table sync across instances

## Architecture Details

**Ported from:** `sim/ai-mesh/`
**Integration:** Ψ-field + Aurora Router + Analytics

**Key Design Decisions:**
- Tabular Q-learning (fast, interpretable, no training required)
- Epsilon-greedy exploration (simple, effective)
- Feature discretization (enables tabular approach)
- SQLite trace store (simple, embedded, no external deps)
- Stateless service (Q-table in memory, persisted on shutdown)

**Production Considerations:**
- Shared Q-table across replicas (use Redis/Cloud SQL)
- Checkpointing strategy (periodic saves + shutdown hook)
- Cold start handling (pre-trained Q-table loaded on startup)
- Epsilon decay schedule (reduce exploration over time)

---

**Status:** Track 2 Phase 1 - Ready for deployment
**Version:** 0.1.0
**License:** VaultMesh
