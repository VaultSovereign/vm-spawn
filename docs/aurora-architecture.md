# Aurora / Rubedo Integration — Architecture

This document shows how treaty-driven compute flows through `vm-spawn`.

## Error & Security Flows

### Failure Modes
- **Bridge down** → queue orders with exponential backoff; raise alert; policy halts new allocations after N retries.
- **Attestation mismatch** → vault-law halts treaty; router fails over to next viable provider.
- **Signature invalid** → order rejected; increment `treaty_failover_events_total`.
- **Replay attack** → nonce cache denies; audit in ledger.

### Metrics & Alerts
Emit Prometheus metrics:
- `treaty_fill_rate` - Fill rate (0.0-1.0)
- `treaty_rtt_ms` - Average round-trip time
- `treaty_provenance_coverage` - Provenance coverage percentage
- `gpu_hours_total` - Total GPU hours consumed
- `treaty_dropped_requests` - Dropped request count
- `treaty_failover_events_total` - Failover event counter

Attach Grafana alert: fill rate < 0.8 for 5m triggers warning.

## Architecture Diagram

```mermaid
flowchart LR
  subgraph VaultCore[VaultMesh Core]
    VL[Vault Core (vault-law)]
    GW[Gateway (vm-fed)]
    SCHED[GPU Scheduler (vm-spawn)]
  end

  subgraph GoldenLayer[Rubedo Economic Layer]
    IL[Intelligence Ledger\n(usage, lineage, reputation)]
    CM[Compute Market\n(credits: mint/burn, bids)]
    AR[Agent Runtime\n(DAOs, services, bots)]
    OBS[Observatory Plane\n(telemetry → KPIs → policy)]
  end

  subgraph Bridges[Law Bridges]
    AX[Axelar / IBC / XCM\n(treaty msgs, attestations)]
  end

  subgraph Energy[GPU Energy Commons]
    G1[Inference Pods (vLLM/Triton)]
    G2[Embeddings / Rerank]
    G3[Fine-tune / LoRA]
  end

  AR -->|requests gpu_time| CM
  CM -->|allocations| SCHED
  SCHED -->|spawn| Energy
  Energy -->|receipts + metrics| IL
  OBS -->|alerts/policy| VL
  VL -->|quota/enforce| SCHED
  GW <-->|treaty orders/acks| AX
  AX <-->|counterparty meshes| GW
  IL -->|mint/burn credits| CM
  IL -->|reputation updates| AR
  OBS -->|KPIs| IL
```

> Stages: **Nigredo → Albedo → Citrinitas → Rubedo**.
