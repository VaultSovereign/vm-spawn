# VaultMesh Service Readiness (2025-10-24)

This file is the single source of truth for current service maturity. It replaces the earlier ad‑hoc decks (`HOW_FAR_FROM_COMPLETE.md`, `CLAIMED_VS_ACTUAL_DASHBOARD.md`, `SERVICES_DEEP_DIVE.md`, `EXPLORATION_EXECUTIVE_SUMMARY.md`, `ANALYSIS_INDEX.md`, `AUDIT_QUICK_REFERENCE.md`). For deeper code notes see `CODE_AUDIT_2025_10_24.md`.

| Service | Claimed | Actual Implementation | Gaps / Next Steps | Owner Notes |
|---------|---------|-----------------------|-------------------|-------------|
| **Scheduler** (`services/scheduler/`) | “10/10 production-ready” | Hardened async scheduler with metrics, health, φ-backoff. Jest config still points at `test/` instead of `tests/`; anchors invoked via npm scripts (no provider integration yet). | Fix Jest root; integrate real anchors once Anchors service is finalized. | ✅ safe to run; mark 9/10 until tests execute automatically. |
| **Ψ-Field** (`services/psi-field/`) | “Consciousness learning system” | FastAPI service computing weighted stability metrics with Guardian interventions; records to Remembrancer, Federation, MQ. No adaptive learning yet. | Reframe docs to “anomaly/stability scoring”; add real learning loop if required. | ✅ production usable for telemetry; marketing copy was overstated. |
| **Aurora Router** (`services/aurora-router/`) | “Phase 1 complete routing Akash/io.net/Render” | Express service with mock provider list and rule-based routing, Prometheus + health. No live provider adapters. | Build provider integrations + optimizer, add fallback to hyperscalers. | ⏳ Phase 1 scaffolding only (~60 % to MVP). |
| **Federation** (`services/federation/`) | “Phase V complete gossip” | Gossip loop written but still uses `MockRemembrancer`, hard-coded node metadata, Bun hash; no deterministic conflict tiers wired. | Replace mock client with real Remembrancer CLI/API, load config from YAML, add conflict resolver & tests. | 🚧 Phase V in progress (≈50 %). |
| **Harbinger** (`services/harbinger/`) | “Phase I operational” | Envelope validation, schema pinning, witness count, provisional receipts written to disk. No signature validation or durable queue. | Implement signature/DID verification, add retry/queue + service management. | 🪪 skeleton usable in dev only. |
| **Sealer** (`services/sealer/`) | “Phase II complete” | CLI that batches provisional events into Merkle tree, writes receipts, no daemon/process manager. | Create long-running service with scheduling/retry; hook into Anchors automatically. | 🧩 functional script (≈30 % of intended service). |
| **Anchors** (`services/anchors/`) | “Phase III operational (BTC/EVM/TSA)” | Typescript writers for EVM/BTC/TSA with manual env vars; no managed secrets, retries, or verification path. | Add secret management, retry/backoff, receipt verification, production runbooks. | ⚠️ integration pending; runnable for labs only. |
| **Analytics** (`services/vaultmesh-analytics/`) | “Next.js dashboard live” | Next.js dashboards for Ψ and routing metrics; history uses mock data; Phase 5 alerting + Remembrancer drill-downs missing. | Implement Phase 5 (alert rules, Remembrancer client, realtime SSE). | ✳️ UI ready for staging; features at ~70 %. |

### Action Items Snapshot
1. **Docs** – Service READMEs must mirror the “Actual Implementation” column (in progress).
2. **Federation & Anchors** – Highest priority gaps before production claims.
3. **Analytics Phase 5** – Alerting + provenance integration targeted next sprint.
4. **Scheduler test fix** – Quick win; unblock CI and reinforce production grade claim.

This page should be updated alongside substantive code changes so the repository stays honest for dev teams and stakeholders.
