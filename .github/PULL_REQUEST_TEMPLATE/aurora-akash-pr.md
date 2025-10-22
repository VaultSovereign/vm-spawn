# Aurora v0.1 — Akash Compute Treaty + Axelar Law Bridge (Scaffold)

## What this adds
- `templates/aurora-treaty-akash.json` (treaty object, signed out-of-band)
- `schemas/axelar-order.schema.json` (order validator)
- `ops/k8s/vm-spawn-llm-infer.yaml` (GPU job template – vLLM)
- `ops/grafana/grafana-dashboard-aurora-akash.json` (KPIs dashboard)
- `policy/vault-law-akash-policy.rs` (quota + region lock; compile to WASM in CI)
- `scripts/aurora-order-submit.sh` (HTTPSig and POST to bridge)
- `scripts/aurora-receipt-verify.sh` (Merkle + timestamp + pin)
- `scripts/aurora-metrics-exporter.py` (Prometheus exporter)
- `docs/aurora-architecture.md` + `docs/VaultMesh-Rubedo-Continuum.svg`

## How to test
1. `python3 scripts/aurora-metrics-exporter.py` → scrape `/metrics` at 9109
2. `bash scripts/aurora-order-submit.sh tmp/order.json` → expect ack
3. `kubectl -n aurora-akash apply -f ops/k8s/vm-spawn-llm-infer.yaml`
4. Emit receipts and pin; import Grafana dashboard

## Notes
- CI should add schema validation for treaty/order JSON.
- Policy should be compiled to WASM and loaded by spawn path before scheduling.