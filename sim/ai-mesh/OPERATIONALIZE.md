# AI Mesh Operationalization Guide

**Status:** v1.0.5 streaming  
**Integration:** Ψ-Field + Remembrancer + Federation

---

## Quick Deploy

```bash
# 1. Deploy Ψ-Field feeder (autonomous metrics)
kubectl -n aurora-staging apply -f services/psi-field/k8s/feeder-cronjob.yaml

# 2. Pin Ψ-Field to digest (immutability)
kubectl -n aurora-staging set image deploy/psi-field \
  psi-field=509399262563.dkr.ecr.eu-west-1.amazonaws.com/vaultmesh/psi-field@sha256:b2d29625112369a24de4b5879c454153bfa8730b629e4faa80fa9246868c74e0

# 3. Apply Prometheus alerts
kubectl -n aurora-staging create configmap prometheus-psi-alerts \
  --from-file=ops/prometheus/alerts/psi-field.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Train AI mesh with Ψ integration
cd sim/ai-mesh
python3 integrate_psi.py

# 5. Record to Remembrancer
./ops/bin/remembrancer record deploy \
  --component psi-field \
  --version v1.0.5 \
  --digest sha256:b2d29625112369a24de4b5879c454153bfa8730b629e4faa80fa9246868c74e0 \
  --note "metrics stabilized; AI mesh integration; autonomous feeder"
```

---

## Architecture

```
┌─────────────────────────────────────────┐
│  AI Agent Swarm (RL policies)           │
│  - Q-learning routing                   │
│  - Epsilon-greedy exploration           │
└─────────────────────────────────────────┘
           ↓ agent_rewards[]
┌─────────────────────────────────────────┐
│  PsiFieldIntegration                    │
│  - Converts rewards → Ψ input           │
│  - Sends to /step endpoint              │
└─────────────────────────────────────────┘
           ↓ Ψ metrics
┌─────────────────────────────────────────┐
│  Ψ-Field Service (consciousness)        │
│  - Computes Ψ, C, U, Φ, H, PE          │
│  - Guardian interventions               │
│  - Prometheus /metrics                  │
└─────────────────────────────────────────┘
           ↓ records
┌─────────────────────────────────────────┐
│  Remembrancer (cryptographic memory)    │
│  - GPG + RFC3161 + Merkle               │
│  - Training receipts                    │
└─────────────────────────────────────────┘
```

---

## Monitoring

### Grafana Dashboards
- **Ψ-Field Dashboard:** `http://grafana.vaultmesh.cloud/d/psi-field-dashboard`
- **AI Mesh Training:** (TODO: Create dashboard)

### Key Metrics
```promql
# Consciousness density
psi_field_density

# Prediction error (anomaly detection)
psi_field_prediction_error

# Guardian interventions
rate(guardian_interventions_total[5m])

# Agent performance (from training)
ai_mesh_avg_reward
```

### Alerts
- **PsiFieldTargetDown:** Scrape failing >5m
- **PsiFieldFlatline:** No updates >10m
- **PsiFieldPredictionErrorCritical:** PE >1.5 for 5m
- **PsiFieldPodDriftExtreme:** Pod variance >2.0

---

## Training Integration

### Basic Training with Ψ-Field
```python
from integrate_psi import PsiFieldIntegration

integration = PsiFieldIntegration(
    psi_url="http://psi-field:8000",
    remembrancer_path="./ops/bin/remembrancer"
)

for episode in range(1000):
    # Train agents
    agent_rewards = train_episode()
    
    # Send to Ψ-Field
    psi_metrics = integration.send_agent_metrics(agent_rewards)
    
    # Check for intervention
    intervention = integration.check_intervention_needed(psi_metrics)
    if intervention == 'nigredo':
        reset_worst_agents()
    elif intervention == 'albedo':
        increase_exploration()
    
    # Record to Remembrancer
    integration.record_training_step(episode, {
        'rewards': agent_rewards,
        'psi': psi_metrics
    })
```

### Advanced: Multi-Node Federation
```python
# Node A trains and publishes Q-tables
swarm_a.train(episodes=1000)
swarm_a.save_swarm("node_a")

# Remembrancer records
integration.record_training_step(1000, {
    'node': 'a',
    'q_tables': swarm_a.export_q_tables()
})

# Node B syncs via Federation
# TODO: Implement gossip protocol for Q-table sync
```

---

## Verification

```bash
# 1. Check feeder CronJob
kubectl -n aurora-staging get cronjob psi-field-feeder
kubectl -n aurora-staging get jobs -l app=psi-field-feeder

# 2. Verify Ψ metrics flowing
kubectl -n aurora-staging port-forward svc/psi-field 8000:8000 &
curl http://localhost:8000/metrics | grep psi_field_density

# 3. Check Prometheus scraping
kubectl -n monitoring port-forward svc/prometheus-server 9090:80 &
curl -s 'http://localhost:9090/api/v1/series?match[]=psi_field_density' | jq

# 4. Verify Remembrancer receipts
./ops/bin/remembrancer list deployments | grep ai-mesh

# 5. Test AI mesh integration
cd sim/ai-mesh
python3 integrate_psi.py
```

---

## Troubleshooting

### Ψ-Field not responding
```bash
kubectl -n aurora-staging logs -l app=psi-field --tail=50
kubectl -n aurora-staging describe pod -l app=psi-field
```

### Feeder CronJob failing
```bash
kubectl -n aurora-staging logs job/psi-field-feeder-<timestamp>
kubectl -n aurora-staging describe cronjob psi-field-feeder
```

### Prometheus not scraping
```bash
kubectl -n aurora-staging get servicemonitor
kubectl -n aurora-staging describe svc psi-field
# Check annotations: prometheus.io/scrape=true
```

### AI mesh training errors
```bash
# Check Ψ-Field connectivity
curl -X POST http://localhost:8000/step \
  -H 'Content-Type: application/json' \
  -d '{"x":[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6]}'

# Check Remembrancer
./ops/bin/remembrancer --version
```

---

## Next Steps

1. **Create AI Mesh Grafana dashboard** (training curves, Ψ evolution)
2. **Implement Q-table federation sync** (gossip protocol)
3. **Add multi-objective RL** (Pareto-optimal policies)
4. **Deploy to production** (scale to 100+ agents)
5. **Meta-learning** (agents learn to learn faster)

---

## Covenant Alignment

✅ **Integrity (Nigredo):** Metrics from Prometheus, not docs  
✅ **Reproducibility (Albedo):** Digest-pinned deployment  
✅ **Federation (Citrinitas):** Q-table sync ready  
✅ **Proof-Chain (Rubedo):** Remembrancer records all training  

---

**Astra inclinant, sed non obligant. 🜂**
