# Ψ-Field Stability Metrics Service

**Version:** v1.0.0
**Status:** Operational (stability scoring)
**Integration:** VaultMesh v4.1-genesis+

## Overview

The Ψ-Field service aggregates per-agent telemetry into a **stability score** (Ψ) that reflects how coherent, anticipatory, and low-noise the system is. It does **not** implement general “consciousness” or learning—it computes a weighted anomaly signal and applies Guardian playbooks (Nigredo/Albedo) when stability degrades. Outputs feed Remembrancer, Aurora federation metrics, and VaultMesh Analytics.

## Architecture Integration

Ψ-Field respects VaultMesh's zero-coupling principle:

1. **Layer 1 (Spawn Elite)**: Generated service structure
2. **Layer 2 (Remembrancer)**: Records memory and protention traces
3. **Layer 3 (Aurora)**: Distributes Ψ metrics across federated nodes

## Key Concepts

### Core Metrics

1. **Continuity (C)**: How well the present binds to the immediate past
2. **Futurity (U)**: Anticipatory grip on near futures
3. **Phase Coherence (Φ)**: Temporal alignment via complex phase
4. **Temporal Entropy (H)**: Uncertainty across retained→predicted spans
5. **Prediction Error (PE)**: Mismatch between realized and expected next latent

### Stability Score (Ψ)

```
ρ = dt / (ε + M)                 // ε small > 0
Ψ = σ(w1*(1/ρ) + w2*C + w3*U + w4*Φ - w5*H - w6*PE)
```

Where:
- `M` is active mnemonic capacity
- `σ` is a squashing function (sigmoid)
- `w*` are configurable weights

## Usage

### API Endpoints (HTTP, FastAPI)

- `POST /init` – Initialize engine parameters
- `GET /params` – Inspect current parameters
- `GET /state` – Read latest Ψ/C/U/Φ/H/PE/M snapshot
- `POST /step` – Submit an observation vector; returns updated metrics
- `GET /health` – Health check
- `GET /metrics` – Prometheus metrics
- `GET /guardian/status` / `GET /guardian/statistics` – Guardian telemetry
- `POST /guardian/nigredo` / `POST /guardian/albedo` – Manual guard playbooks
- `POST /record` / `POST /remembrancer/record` – Explicit Remembrancer recording hooks
- `GET /federation/metrics` / `POST /federation/swarm` – Swarm aggregation

### Federation Endpoints

- `GET /federation/metrics`: Get agent metrics
- `POST /federation/swarm`: Calculate swarm metrics

### Example

```bash
# Initialize the Ψ-field
curl -X POST http://localhost:8000/init -H "Content-Type: application/json" \
  -d '{"dt": 0.2, "W_r": 3.0, "H": 2.0, "N": 8}'

# Execute a step
curl -X POST http://localhost:8000/step -H "Content-Type: application/json" \
  -d '{"x_k": [0.1, 0.2, 0.3, 0.4]}'
```

## Remembrancer Integration

Ψ-Field can emit two trace types to the Remembrancer CLI/API:

1. **Memory traces**: Consolidated experiences when stability is in-range
2. **Protention traces**: Forward projections for cross-agent alignment

### Command Examples

```bash
# View recorded memory traces
./ops/bin/remembrancer query "component:psi-field AND type:memory"

# View protention commitments
./ops/bin/remembrancer query "component:psi-field AND type:protention"
```

## Aurora Federation Integration

Ψ-Field participates in swarm metrics through Aurora:

```
C_swarm = mean_a C_k^a
Φ_swarm = |mean_a exp(i * Phase(φ_k^a))|
U_swarm = mean_a U_k^a
Ψ_swarm = σ(v1*C_swarm + v2*Φ_swarm + v3*U_swarm - v4*H_swarm)
```

## Calibration & Defaults

- `dt = 200 ms`, `W_r = 3 s`, `H = 2 s`, `N = 8 rollouts`, `C_w = 32 traces`
- Weights: `w1=1.0, w2=0.8, w3=0.6, w4=0.6, w5=0.7, w6=0.7`
- Squash: `σ(x) = 1/(1+e^{-x})`
- `λ=0.6` (time dilation strength), `dt_min=50 ms`, `dt_max=500 ms`
Sat Oct 25 11:43:38 AM UTC 2025 — CI smoke
