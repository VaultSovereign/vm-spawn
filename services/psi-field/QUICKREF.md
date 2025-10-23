# PSI-Field Quick Reference

## Environment Variables

```bash
AGENT_ID=psi-agent-01              # Agent identifier
PSI_BACKEND=kalman                 # simple|kalman|seasonal
PSI_INPUT_DIM=16                   # Input dimension
PSI_LATENT_DIM=32                  # Latent dimension
RABBIT_ENABLED=1                   # 0|1
RABBIT_URL=amqp://guest:guest@rabbitmq:5672/
RABBIT_EXCHANGE=swarm
REMEMBRANCER_API=http://remembrancer:8080
```

## Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/step` | POST | Execute PSI step |
| `/state` | GET | Current state |
| `/guardian/status` | GET | Threat assessment |
| `/guardian/statistics` | GET | Guardian stats |
| `/guardian/nigredo` | POST | Apply Nigredo |
| `/guardian/albedo` | POST | Apply Albedo |
| `/metrics` | GET | Prometheus metrics |

## Quick Commands

```bash
# Single backend
docker compose up -d

# Dual backend (Kalman + Seasonal)
docker compose -f docker-compose.psiboth.yml up -d --build

# Smoke test
./smoke-test-dual.sh

# Run tests
pytest -q

# Commit fixes
./commit-fixes.sh
```

## Curl Examples

```bash
# Health check
curl http://localhost:8000/health

# Execute step
curl -X POST http://localhost:8000/step \
  -H 'content-type: application/json' \
  -d '{"x":[0.1,0.2,0.3,0.4,0.0,-0.1,0.05,0.2,0.1,0.0,0.05,-0.05,0.12,0.0,0.03,0.02], "apply_guardian": true}'

# Guardian stats
curl http://localhost:8000/guardian/statistics

# Apply Nigredo
curl -X POST http://localhost:8000/guardian/nigredo
```

## RabbitMQ Routing Keys

- Telemetry: `swarm.<AGENT_ID>.telemetry`
- Guardian alerts: `guardian.alerts`

## Backend Characteristics

| Backend | Best For | PE Behavior | U Behavior |
|---------|----------|-------------|------------|
| **simple** | General | Baseline | Baseline |
| **kalman** | Structured signals | Lower | Improves |
| **seasonal** | Cyclic patterns | Drops on cycles | Stabilizes |

---

**Astra inclinant, sed non obligant.**
