# Dual-Backend PSI Field Deployment

Run two PSI agents side-by-side with different backends (Kalman + Seasonal).

## Quick Start (Docker Compose)

```bash
# Start both agents + RabbitMQ + Remembrancer
docker compose -f docker-compose.psiboth.yml up -d --build

# Wait 10s for startup
sleep 10

# Smoke test
./smoke-test-dual.sh
```

**Endpoints:**
- Kalman: http://localhost:8001
- Seasonal: http://localhost:8002
- RabbitMQ UI: http://localhost:15672 (guest/guest)
- Remembrancer: http://localhost:8080

## Quick Start (Kubernetes)

```bash
# Deploy both agents
kubectl apply -f k8s/psi-both.yaml

# Port-forward for testing
kubectl port-forward svc/psi-kalman-01 8001:8000 &
kubectl port-forward svc/psi-seasonal-01 8002:8000 &

# Smoke test
./smoke-test-dual.sh
```

## What You'll See

**Kalman Backend:**
- Lower PE for structured signals
- Smoother short-term futures
- Better U (understanding) on stable inputs
- Routing key: `swarm.psi-kalman-01.telemetry`

**Seasonal Backend:**
- Picks up daily/weekly cycles
- PE drops on cyclic inputs
- U stabilizes around season phase
- Routing key: `swarm.psi-seasonal-01.telemetry`

## Guardian Statistics

Both agents use **AdvancedGuardian** by default:

```bash
curl http://localhost:8001/guardian/statistics | jq
# {"kind": "advanced", "interventions": 0, "psi_history_len": 42, ...}

curl http://localhost:8002/guardian/statistics | jq
# {"kind": "advanced", "interventions": 0, "psi_history_len": 38, ...}
```

## RabbitMQ Routing

Check exchanges in RabbitMQ UI:
- Exchange: `swarm`
- Keys: `swarm.psi-kalman-01.telemetry`, `swarm.psi-seasonal-01.telemetry`
- Guardian alerts: `guardian.alerts`

## Environment Variables

| Var | Kalman | Seasonal |
|-----|--------|----------|
| `AGENT_ID` | psi-kalman-01 | psi-seasonal-01 |
| `PSI_BACKEND` | kalman | seasonal |
| `PSI_INPUT_DIM` | 16 | 16 |
| `PSI_LATENT_DIM` | 32 | 32 |
| `RABBIT_ENABLED` | 1 | 1 |

## Cleanup

```bash
# Docker Compose
docker compose -f docker-compose.psiboth.yml down -v

# Kubernetes
kubectl delete -f k8s/psi-both.yaml
```

---

**Astra inclinant, sed non obligant.**
