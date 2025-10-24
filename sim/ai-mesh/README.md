# AI Mesh Simulator

Multi-agent reinforcement learning for autonomous infrastructure routing.

## Architecture

```
┌─────────────────────────────────────────┐
│  Agent Swarm (10-100 agents)            │
│  - Q-learning routing policies          │
│  - Epsilon-greedy exploration           │
│  - Experience replay                    │
└─────────────────────────────────────────┘
           ↓ publishes metrics
┌─────────────────────────────────────────┐
│  Ψ-Field Coordinator                    │
│  - Aggregates agent performance         │
│  - Detects anomalies (PE > 0.7)         │
│  - Triggers interventions               │
└─────────────────────────────────────────┘
           ↓ coordinates via
┌─────────────────────────────────────────┐
│  Federation Layer                       │
│  - Gossip protocol for Q-table sync     │
│  - Merkle-verified decisions            │
│  - Remembrancer records all actions     │
└─────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Start Ψ-Field service
cd services/psi-field
docker-compose up -d

# 2. Run AI mesh simulation
cd sim/ai-mesh
python3 train.py --agents 10 --episodes 1000

# 3. View results
python3 visualize.py out/training_metrics.csv
```

## Components

### `agent.py`
- **RoutingAgent**: Q-learning agent for provider selection
- **State**: Environment observation (latencies, prices, capacities)
- **compute_reward()**: Multi-objective reward function

### `swarm.py`
- **SwarmCoordinator**: Manages multiple agents
- **Ψ-Field integration**: Sends swarm metrics for consciousness tracking
- **Guardian interventions**: Nigredo (reset) / Albedo (explore)

### `train.py`
- Training loop for agent swarm
- Integrates with existing multi-provider simulator
- Outputs: Q-tables, training curves, decision logs

### `visualize.py`
- Plot training progress
- Compare agent vs baseline routing
- Show swarm consciousness evolution

## Training

```bash
# Basic training (10 agents, 1000 episodes)
python3 train.py

# Advanced training
python3 train.py \
  --agents 50 \
  --episodes 5000 \
  --learning-rate 0.05 \
  --epsilon 0.2 \
  --psi-field http://psi-field:8000

# Resume from checkpoint
python3 train.py --load out/swarm_checkpoint.json
```

## Evaluation

```bash
# Compare AI vs baseline
python3 evaluate.py \
  --ai-agents out/swarm_final.json \
  --baseline-config ../multi-provider-routing-simulator/config/workloads.json \
  --steps 1000

# Expected improvements:
# - Fill rate: 95% → 98%
# - Avg cost: $2.44 → $2.10
# - Avg latency: 330ms → 290ms
```

## Integration with Remembrancer

All agent decisions are recorded:

```bash
# Record training run
./ops/bin/remembrancer record deploy \
  --component ai-mesh-training \
  --version v1.0 \
  --evidence sim/ai-mesh/out/swarm_final.json

# Query agent decisions
./ops/bin/remembrancer query "ai-mesh routing decisions"
```

## Federation

Agents can sync Q-tables across nodes:

```python
from swarm import SwarmCoordinator

# Node A
swarm_a = SwarmCoordinator(n_agents=10, n_providers=7)
swarm_a.save_swarm("node_a")

# Node B loads and continues training
swarm_b = SwarmCoordinator(n_agents=10, n_providers=7)
# TODO: Implement Q-table federation sync
```

## Metrics

### Agent Performance
- `q_table_size`: Number of states explored
- `avg_reward`: Average reward per episode
- `epsilon`: Current exploration rate

### Swarm Consciousness (Ψ-Field)
- `Ψ (psi)`: Aggregate consciousness density
- `C (continuity)`: Swarm coherence
- `PE (prediction_error)`: Anomaly detection
- `interventions`: Guardian actions triggered

### Routing Quality
- `fill_rate`: % requests successfully routed
- `avg_cost`: Average cost per request
- `avg_latency`: Average latency (ms)

## Next Steps

1. **Implement `train.py`**: Training loop with simulator integration
2. **Add `visualize.py`**: Plot training curves and swarm metrics
3. **Federation sync**: Gossip protocol for Q-table sharing
4. **Multi-objective RL**: Pareto-optimal routing policies
5. **Meta-learning**: Agents learn to learn faster
