# VaultMesh Multi‑Provider Routing War‑Game

This pack simulates VaultMesh acting as a **Sovereignty Layer** across multiple DePIN providers
(Akash, io.net, Render, Flux, Aethir, Vast.ai, Salad) using an Aurora‑style treaty model.

## Contents

- `config/providers.json` – provider profiles (prices, latency, regions, credits)
- `config/workloads.json` – tenants, workload mix, scenarios (outages, spikes)
- `sim/sim.py` – simulation engine (Router, ScenarioEngine, metrics aggregation)
- `sim/test_router.py` – unit tests for routing filter logic
- `out/` – generated CSVs and charts after a run (git-ignored)

## Quick Run

```bash
# From repository root
make sim-run

# Or directly
python3 sim/multi-provider-routing-simulator/sim/sim.py
```

### Parameterized Runs

Override simulation parameters via environment variables:

```bash
# Run with custom seed and step count
SEED=99 STEPS=200 make sim-run

# Quick 50-step drill
STEPS=50 make sim-run
```

## Outputs

After running, check `out/` directory:

- `out/step_metrics.csv` – per‑step totals (fill rate, dropped, avg cost, avg latency, credits)
- `out/routing_decisions.csv` – per‑request decision log
- `out/provider_metrics_over_time.csv` – provider snapshots (latency, price, capacity, reputation)
- `out/chart_*.png` – matplotlib visualizations (fill rate, latency, cost, capacity, dropped requests)

## War‑Game Scenarios (Preloaded)

The default configuration includes realistic DePIN failure modes:

- **Step 20**: Price spike on Vast.ai (1.6x multiplier)
- **Step 35**: Akash outage (10 steps duration)
- **Step 50**: Render latency spike (+200ms, 15 steps)
- **Step 70**: io.net capacity surge (1.5x, 25 steps)
- **Step 90**: Salad reputation drop (-10 points, 20 steps)

Edit `config/workloads.json` → `scenarios[]` to customize events.

## Routing Logic

The router implements multi-constraint optimization:

1. **Filter Phase** – Eliminate incompatible providers:
   - Region mismatch (unless provider supports `"global"`)
   - GPU type unavailable
   - Latency exceeds tenant SLA (`max_latency_ms`)
   - Reputation below tenant threshold (`min_reputation`)
   - Price exceeds tenant budget (`max_price`)
   - Insufficient remaining capacity for request

2. **Scoring Phase** – Rank viable providers by weighted utility:
   ```
   score = (w_price × 1/price) +
           (w_latency × 1/latency) +
           (w_reputation × reputation/100) +
           (w_availability × capacity_remaining/capacity_total)
   ```
   Weights are tenant-specific (see `config/workloads.json` → `tenants[*].weights`)

3. **Selection** – Choose highest-scoring provider, deduct capacity

## Configuration Knobs

All parameters are tunable without code changes:

### Tenant Behavior (`config/workloads.json`)

- **Routing weights**: `tenants[*].weights` – Adjust price/latency/reputation/availability priorities
- **Latency SLA**: `tenants[*].max_latency_ms` – Maximum acceptable provider latency
- **Budget**: `tenants[*].budget_usd_per_step` – Per-step spending cap
- **Reputation floor**: `tenants[*].min_reputation` – Minimum provider reputation (0-100)
- **Workload mix**: `tenants[*].mix` – Distribution of workload types (llm_training, llm_inference, etc.)

### Provider Profiles (`config/providers.json`)

- **Pricing**: `base_price_usd_per_hour` per GPU type
- **Latency**: `base_latency_ms` (bridge RTT + network)
- **Capacity**: `capacity_gpu_hours_per_step` (per-step throughput)
- **Reputation**: `reputation` (initial score 0-100)
- **Regions**: `regions[]` (or `["global"]` for worldwide)

### Simulation Parameters

- **Duration**: `STEPS=N` environment variable or `workloads.json` → `simulation.steps`
- **Seed**: `SEED=N` environment variable or `workloads.json` → `simulation.seed`

## Metrics Exporter (Prometheus)

Expose simulator telemetry for Grafana dashboards:

```bash
# Terminal 1: Run simulator
make sim-run

# Terminal 2: Start metrics exporter
make sim-metrics-run
```

The exporter serves Prometheus metrics on **port 9110** at `/metrics`:

- `treaty_fill_rate{treaty_id="SIM-AGG"}` – Fill rate (0.0-1.0)
- `treaty_rtt_ms{treaty_id="SIM-AGG"}` – Average latency
- `gpu_hours_total{treaty_id="SIM-AGG"}` – Cumulative GPU hours consumed
- `provider_latency_ms{provider_id="akash"}` – Per-provider latency
- `provider_reputation{provider_id="ionet"}` – Per-provider reputation

### Grafana Integration

1. Add Prometheus data source pointing to `localhost:9110`
2. Import or create panels using queries like:
   ```promql
   treaty_fill_rate{treaty_id="SIM-AGG"}
   rate(gpu_hours_total{treaty_id="SIM-AGG"}[5m])
   provider_reputation
   ```

See [ops/grafana/grafana-dashboard-aurora-akash.json](../../ops/grafana/grafana-dashboard-aurora-akash.json) for reference dashboard.

## Testing

Run unit tests to validate routing logic:

```bash
python3 sim/multi-provider-routing-simulator/sim/test_router.py
```

Tests cover:
- Price filtering
- Latency SLA enforcement
- Reputation thresholds
- Capacity tracking and depletion
- Region compatibility
- GPU type matching

## CI/CD Integration

The simulator runs automatically in GitHub Actions on PR changes:

- Workflow: `.github/workflows/sim-ci.yml`
- Artifacts uploaded: CSV outputs + PNG charts
- Retention: 30 days

Access artifacts via PR "Checks" tab → "Simulator CI" → "war-game-artifacts"

## Tactical Evolution

Future enhancements:

1. **Closed-loop policy**: Feed `fill_rate < 0.8` alerts into `vault-law` policy suggestions
2. **Credit auction**: Simulate dynamic credit pricing with demand-based minting
3. **Multi-step routing**: Model request retries and failover cascades
4. **Provider SLO tracking**: Calculate uptime percentages from outage events
5. **Cost optimization**: Add portfolio theory for budget allocation across providers

