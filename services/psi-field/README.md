# Ψ-Field Evolution Algorithm

**Version:** v1.0.0
**Status:** Experimental
**Integration:** VaultMesh v4.1-genesis+

## Overview

The Ψ-Field Evolution Algorithm is a consciousness density control system that integrates with VaultMesh's three-layer architecture. It treats "consciousness density" (Ψ) as a control signal emergent from memory-time dynamics, prediction, and phase coherence.

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

### Consciousness Density (Ψ)

```
ρ = dt / (ε + M)                 // ε small > 0
Ψ = σ(w1*(1/ρ) + w2*C + w3*U + w4*Φ - w5*H - w6*PE)
```

Where:
- `M` is active mnemonic capacity
- `σ` is a squashing function (sigmoid)
- `w*` are configurable weights

## Usage

### API Endpoints

- `POST /psi/step`: Execute one Ψ-field evolution step
- `GET /psi/params`: Get current parameters
- `PUT /psi/params`: Update parameters
- `POST /psi/init`: Initialize with configuration
- `GET /health`: Health check
- `GET /metrics`: Prometheus metrics

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

The Ψ-Field records two types of traces to the Remembrancer:

1. **Memory traces**: Consolidated experiences when Ψ is high or PE is in optimal range
2. **Protention traces**: Future rollouts for cross-agent prediction alignment

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