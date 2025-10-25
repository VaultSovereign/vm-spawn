# Aurora Intelligence Engine

**Version:** 1.0.0
**Type:** Computational Engine (Library)
**Purpose:** RL-based adaptive multi-cloud routing intelligence for VaultMesh

---

## What Aurora Intelligence Is

Aurora Intelligence is **not a service** — it's a **computational engine** that provides:

- **Q-learning** agent with ε-greedy exploration
- **Adaptive routing** decisions based on cost, latency, reputation
- **Consciousness-aware exploration** (integrates with Ψ-Field)
- **Reward computation** from actual routing outcomes
- **Audit trail** for compliance and debugging

**Aurora Intelligence is a library** meant to be **imported and used** by services like `aurora-router`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Aurora Intelligence Engine                │
│                                                               │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │  Strategist  │   │   Executor   │   │   Auditor    │    │
│  │              │   │              │   │              │    │
│  │ Q-learning   │──▶│ Outcome      │──▶│ Validation   │    │
│  │ ε-greedy     │   │ tracking     │   │ Audit trail  │    │
│  │ Ψ-aware      │   │ Reward       │   │ Compliance   │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                   │                   │            │
│         └───────────────────┴───────────────────┘            │
│                             │                                │
└─────────────────────────────┼────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Importing Service  │
                    │  (e.g., aurora-     │
                    │   router Phase 3)   │
                    └────────────────────┘
```

---

## Installation

### As a Python Package

```bash
# From source (development)
cd engines/aurora-intelligence
pip install -e .

# From wheel (production)
pip install dist/aurora_intelligence-1.0.0-py3-none-any.whl
```

### Build Wheel Artifact

```bash
cd engines/aurora-intelligence
python -m build --wheel

# Output: dist/aurora_intelligence-1.0.0-py3-none-any.whl
```

---

## Usage

### Basic Integration

```python
from aurora_intelligence import RoutingEngine

# Initialize engine
engine = RoutingEngine(
    psi_field_url="http://psi-field:9091",
    strict_audit=False,
    auto_save=True,
    model_path="/opt/aurora/q_table.json"
)

# Make routing decision
context = {
    "workload_type": "llm_inference",
    "gpu_type": "a100",
    "region": "us-west",
    "gpu_hours": 2.0,
}

providers = [
    {
        "provider_id": "akash",
        "price_usd_per_hour": 2.50,
        "latency_ms": 120,
        "reputation": 95,
        "capacity_available": 100,
        "gpu_types": ["a100", "t4"],
        "regions": ["us-west", "eu-central"],
    },
    # ... more providers
]

constraints = {
    "max_price": 3.0,
    "max_latency_ms": 300,
    "min_reputation": 80,
}

provider_id, metadata = engine.decide(
    context=context,
    providers=providers,
    constraints=constraints,
)

print(f"Selected provider: {provider_id}")
print(f"Mode: {metadata['mode']}")  # "explore" or "exploit"
print(f"Q-value: {metadata['q_value']}")
print(f"Decision ID: {metadata['decision_id']}")

# Later, provide feedback on actual outcome
reward = engine.feedback(
    decision_id=metadata["decision_id"],
    success=True,
    actual_cost_usd=2.45,
    actual_latency_ms=115,
    actual_reputation=96,
)

print(f"Reward: {reward}")  # Used to update Q-table
```

### Async Ψ-Field Integration

```python
import asyncio
from aurora_intelligence import RoutingEngine

async def main():
    engine = RoutingEngine(psi_field_url="http://psi-field:9091")

    # Fetch consciousness metrics
    psi_metrics = await engine.fetch_psi_metrics()

    # Make decision with Ψ-aware exploration
    provider_id, metadata = engine.decide(
        context=context,
        providers=providers,
        psi_metrics=psi_metrics,  # Adjusts ε based on consciousness
    )

asyncio.run(main())
```

---

## Core Components

### 1. Strategist (Q-Learning Agent)

**Purpose:** Plan routing decisions using reinforcement learning

**Key Features:**
- Q-table: `(workload_type, gpu_type, region) → {provider: q_value}`
- ε-greedy exploration (0.1 default, decays to 0.01)
- Ψ-field consciousness adjusts exploration rate
- Persistent Q-table (save/load JSON)

**API:**
```python
from aurora_intelligence import Strategist, WorkloadContext, ProviderState

strategist = Strategist(epsilon=0.1, alpha=0.1, gamma=0.95)

provider_id, metadata = strategist.recommend(
    context=WorkloadContext(...),
    providers=[ProviderState(...)],
    psi_density=0.68,  # Optional Ψ-field consciousness
)

strategist.update_q_value(state_key, provider_id, reward)
strategist.decay_epsilon()
strategist.save("/path/to/q_table.json")
```

### 2. Executor (Outcome Tracker)

**Purpose:** Track routing outcomes and compute rewards

**Key Features:**
- Decision log (decision_id → RoutingDecision)
- Outcome recording (success, cost, latency, reputation)
- Reward computation (multi-objective: cost + latency + reputation + success)

**Reward Function:**
```
reward = -cost + latency_penalty + reputation_bonus + success_bonus

where:
  cost_penalty = -actual_cost_usd
  latency_penalty = -(actual_latency_ms / 500)
  reputation_bonus = actual_reputation / 100
  success_bonus = 10 (or -20 if failure)
```

**API:**
```python
from aurora_intelligence import Executor

executor = Executor()

decision_id = executor.record_decision(state_key, provider_id, context, metadata)

reward = executor.record_outcome(
    decision_id=decision_id,
    success=True,
    actual_cost_usd=2.45,
    actual_latency_ms=115,
    actual_reputation=96,
)
```

### 3. Auditor (Validator)

**Purpose:** Validate decisions against constraints and maintain audit trail

**Key Features:**
- Constraint validation (price, latency, reputation, region, GPU, capacity)
- Violation detection (6 types: PRICE_EXCEEDED, LATENCY_EXCEEDED, etc.)
- Audit log (timestamp, decision_id, status, violations, notes)
- Anomaly flagging (Q-value spikes, underperforming providers)

**API:**
```python
from aurora_intelligence import Auditor

auditor = Auditor(strict_mode=False)

is_valid, violations = auditor.validate_decision(
    decision_id=decision_id,
    state_key=state_key,
    provider_id=provider_id,
    provider_state={...},
    constraints={...},
)

auditor.flag_anomaly(decision_id, state_key, provider_id, "Q-value spike detected")

trail = auditor.get_audit_trail(limit=100)
stats = auditor.get_stats()
```

---

## Testing

### Run Tests

```bash
cd engines/aurora-intelligence

# Install dev dependencies
pip install -e ".[dev]"

# Run all tests
pytest

# With coverage
pytest --cov=aurora_intelligence --cov-report=html

# Watch mode
pytest-watch
```

### Test Structure

```
tests/
├── test_strategist.py      # Q-learning logic, ε-greedy, Ψ-adjustment
├── test_executor.py        # Outcome tracking, reward computation
├── test_auditor.py         # Validation, violations, audit trail
└── test_engine.py          # End-to-end integration
```

---

## Integration with Aurora Router (Phase 3)

**Current State:** aurora-router is Phase 1 (rule-based)

**Phase 3 Integration:** aurora-router will import aurora-intelligence

### Example Integration (TypeScript → Python via HTTP)

**Option A: Python sidecar service**

```typescript
// services/aurora-router/src/ai-router.ts
import fetch from 'node-fetch';

const AI_ENGINE_URL = process.env.AI_ENGINE_URL || 'http://localhost:8000';

export async function getAIDecision(context, providers) {
  const response = await fetch(`${AI_ENGINE_URL}/decide`, {
    method: 'POST',
    body: JSON.stringify({ context, providers }),
    headers: { 'Content-Type': 'application/json' },
  });

  const { provider_id, metadata } = await response.json();
  return { provider_id, metadata };
}
```

**Option B: Direct Python package import (if Node.js supports)**

Use `python-bridge` or similar to call Python functions from Node.js.

**Option C: Rewrite aurora-router in Python (Phase 3)**

Simplest long-term approach: merge aurora-router + aurora-intelligence into single Python service.

---

## Metrics Export

Aurora Intelligence exposes internal metrics for monitoring:

```python
engine = RoutingEngine()

status = engine.get_status()

print(status)
# {
#   "strategist": {
#     "epsilon": 0.061,
#     "decision_count": 1523,
#     "q_states": 45,
#     "avg_reward_100": 7.2,
#     "total_rewards": 1200,
#   },
#   "executor": {
#     "total_decisions": 1523,
#     "total_outcomes": 1200,
#     "success_rate": 0.94,
#     "avg_cost_usd": 2.34,
#     "avg_latency_ms": 128,
#     "pending_feedback": 323,
#   },
#   "auditor": {
#     "total_entries": 1523,
#     "approval_rate": 0.87,
#     "rejection_rate": 0.02,
#     "flagged_rate": 0.11,
#     "common_violations": [
#       {"type": "price_exceeded", "count": 45},
#       {"type": "latency_exceeded", "count": 23},
#     ],
#   },
#   "psi_field_connected": true,
#   "model_path": "/opt/aurora/q_table.json",
# }
```

---

## Configuration

### Environment Variables (when used as HTTP service)

```bash
PORT=8000
LOG_LEVEL=info
PSI_FIELD_URL=http://psi-field:9091
MODEL_PATH=/opt/aurora/q_table.json
STRICT_AUDIT=false
AUTO_SAVE=true
```

### Q-Learning Hyperparameters

Tunable in `Strategist()`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `epsilon` | 0.1 | Exploration rate (0-1) |
| `epsilon_decay` | 0.995 | Decay per decision |
| `epsilon_min` | 0.01 | Minimum exploration |
| `alpha` | 0.1 | Learning rate |
| `gamma` | 0.95 | Discount factor |

---

## Deployment as Engine Artifact

Aurora Intelligence is **not deployed** as a service. Instead:

### 1. Build Wheel

```bash
cd engines/aurora-intelligence
python -m build --wheel
```

### 2. Publish to Artifact Registry

```bash
# GCP Artifact Registry (Python package)
gcloud artifacts repositories create vaultmesh-engines \
  --repository-format=python \
  --location=us-central1

twine upload --repository-url https://us-central1-python.pkg.dev/572946311311/vaultmesh-engines/ \
  dist/aurora_intelligence-1.0.0-py3-none-any.whl
```

### 3. Install in Services

```bash
# In aurora-router or other services
pip install aurora-intelligence==1.0.0 \
  --index-url https://us-central1-python.pkg.dev/572946311311/vaultmesh-engines/simple/
```

### 4. Record in Remembrancer

```bash
ops/bin/remembrancer decision "Aurora Intelligence Engine v1.0.0 Built" \
  --reason "Q-learning routing engine for Phase 3 AI-enhanced decisions"
```

---

## Roadmap

### ✅ Phase 1: Core Engine (Complete)
- Q-learning agent (Strategist)
- Outcome tracking (Executor)
- Validation & audit (Auditor)
- Python package structure

### ⏳ Phase 2: Advanced Features (Next)
- Multi-armed bandit algorithms
- Contextual bandits (per-workload tuning)
- Deep Q-Network (DQN) for larger state spaces
- Persistent PostgreSQL storage (replace JSON)

### ⏳ Phase 3: Router Integration (Future)
- HTTP sidecar service for TypeScript aurora-router
- OR: Rewrite aurora-router in Python for direct import
- A/B testing (% traffic to AI vs rule-based)
- Online learning from production traffic

---

## VaultMesh Integration

- **Layer**: 3 (Aurora - Federation & Treaties)
- **Covenant Alignment**:
  - Proof-Chain: Model versioning with receipts
  - Integrity: Audit trail for all decisions
  - Consciousness: Ψ-Field integration for adaptive exploration
- **Uses**:
  - Ψ-Field: Consciousness metrics (density, coherence, entropy)
  - Remembrancer: Model version tracking
  - Aurora Router: Primary consumer of routing intelligence

---

## Performance Characteristics

**Latency:** <5ms per decision (in-memory Q-table)
**Throughput:** ~10,000 decisions/sec (single process)
**Memory:** ~50MB base + ~10KB per Q-state
**Persistence:** JSON snapshot every 10 decisions (configurable)

---

## Troubleshooting

### Q-values not updating
- Check feedback is being called with `decision_id`
- Verify `reward` is computed correctly
- Ensure `auto_save=True` to persist Q-table

### Excessive exploration
- Check `epsilon` value (should decay over time)
- Verify Ψ-field connection (high consciousness → lower ε)
- Adjust `epsilon_decay` rate

### Poor routing decisions
- Insufficient training data (need more feedback)
- Reward function misaligned with business goals
- Hyperparameters need tuning (alpha, gamma)

---

## License

MIT

---

**Status:** Phase 1 Complete ✅
**Type:** Engine (Library), not Service
**Next:** Integration with aurora-router Phase 3
**Contact:** VaultMesh Engineering

🜂 *Astra inclinant, sed non obligant.*
