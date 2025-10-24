# VaultMesh — Phase VI Evolution Plan
**Date:** 2025-10-24  
**Author:** GPT-5 Pro (co-pilot to Sovereign)  
**North Star:** *Position VaultMesh as Earth’s Civilization Ledger — a living archive of law, memory, economy, and guardianship.*

---

## Executive Summary
This plan turns the operational loop — **intake → seal → anchor → route → sync → learn → visualize** — into an **autonomous epoch**. The weekend’s work is organized into 5 workstreams with concrete tasks, commands, and acceptance criteria.

**Primary outcomes by end of weekend:**
- Federation runs with **real Remembrancer**, DID allowlist, and deterministic conflict tiers (**BTC > EVM > TSA**).
- Anchoring is **hands‑off**: managed secrets, retry/backoff, and **receipt verification** persisted to disk.
- Harbinger + Sealer migrate from filesystem cadence to a **durable queue + job runner** with automatic retries.
- Analytics gets **Phase V alerting hooks** and **RBAC** (OIDC) wrapper; Ψ‑Field Guardian runs in **advanced** mode by default.
- Baseline **ops hardening** (TLS, secrets, container policy) applied across the stack.

---

## Workstream A — Federation (Truth Gossip)
**Goal:** Replace MockRemembrancer, enforce identity, and resolve conflicts deterministically.

### A1. Remembrancer Client Integration
- **Task:** Swap `MockRemembrancer` for a real client and implement `getProof(chain)` + `getRoot(height)` calls.
- **Config:** `federation/config.yaml` (schema below).
- **Acceptance:** Node joins cluster and fetches peer proofs; `GET /federation/peers` shows live identities.

### A2. DID Allowlist (Peer Identity)
- **Task:** Enforce peers via `did:key` / `did:pkh` list; sign gossip envelopes (JWS).
- **Acceptance:** Unknown peers are rejected; signed envelopes validate with `kid` rotation support.

### A3. Deterministic Conflict Law
- **Task:** Implement `resolve(proofs[])` with hard tiers and stable tie‑breakers:
  1) **Tier:** BTC > EVM > TSA  
  2) **Tie:** earlier **anchor timestamp** first  
  3) **Final:** lower **tx hash lexicographic** as last resort
- **Acceptance:** Multi‑anchor batches converge to the same canonical root across all nodes.

### A4. Live Merkle Recompute
- **Task:** When proofs conflict, recompute Merkle from source events to verify candidate roots.
- **Acceptance:** Bad roots trigger quarantine + alert and do not advance local tip.

#### Example: `federation/config.yaml`
```yaml
node_id: "vm-node-01"
node_did: "did:key:z6Mkv..."
gossip:
  interval_ms: 1500
  max_peers: 16
peers_allowlist:
  - "did:key:z6MkA_peerA"
  - "did:pkh:eip155:1:0xabc..."
conflict_policy:
  order: ["BTC", "EVM", "TSA"]
  tie_breakers: ["earliest_anchor_ts", "lowest_tx_hash"]
  quarantine_minutes: 15
remembrancer:
  url: "http://remembrancer:7070"
  timeout_ms: 3000
```

**Commands**
```bash
make federation    # build + run
curl -s localhost:7077/healthz
curl -s localhost:7077/federation/peers
```

---

## Workstream B — Anchors (Autonomous Proof Chain)
**Goal:** Secrets-managed, resilient anchoring with receipt verification for BTC & EVM.

### B1. Secrets Management
- **Task:** Move keys from env files to SOPS (age) or Vault. Starter (SOPS) included.
- **Acceptance:** `make anchor-*` reads decrypted env at runtime; no raw secrets on disk.

**Bootstrap**
```bash
age-keygen -o ~/.config/age/keys.txt
echo "creation_rules:
  - paths: ['secrets/**']
    key_groups:
    - age:
      - $(grep -o 'age1.*' ~/.config/age/keys.txt)" > .sops.yaml
mkdir -p secrets && touch secrets/evm.env secrets/btc.env
sops -e -i secrets/evm.env && sops -e -i secrets/btc.env
```

### B2. Anchor Orchestrator + Backoff
- **Task:** Add `anchor-manager` with exponential backoff + jitter and idempotent handoffs.
- **Acceptance:** If EVM/BTC RPC is down, retries escalate to 30m max, then alert.

### B3. Receipt Verification & Persistence
- **Task:** After each anchor, verify chain inclusion and persist receipts under `anchors/receipts/`.
- **Acceptance:** `verify_anchor --root <MERKLE_ROOT>` returns `OK` for both BTC and EVM.

**Receipt structure**
```json
{
  "root": "0xMERKLE",
  "chain": "EVM",
  "network": "mainnet",
  "txHash": "0x...",
  "blockNumber": 21033456,
  "anchorTs": "2025-10-24T12:34:56Z",
  "verifier": "v1.0.0",
  "status": "verified"
}
```

**CLI skeleton**
```bash
make anchor-evm      # wraps: node scripts/anchor-evm.js
make anchor-btc      # wraps: node scripts/anchor-btc.js
scripts/verify-anchor.sh --root 0xMERKLE --evm --btc
```

---

## Workstream C — Harbinger + Sealer (Queues & Jobs)
**Goal:** From filesystem triggers to durable queue + automatic retries.

### C1. Event Intake → Validation Queue
- **Task:** Introduce Redis Streams + BullMQ (or NATS JetStream). Starter uses Redis for speed.
- **Acceptance:** Events land in `events:intake`; valid signed events move to `events:validated`.

### C2. Sealer Batch Worker
- **Task:** Batch by `(maxItems | maxInterval)` and produce Merkle + batch manifest.
- **Acceptance:** Failed seals auto‑retry (max 5) with dead‑letter `sealer:dlq` + alerting.

### C3. Long‑Lived Process Control
- **Task:** systemd services + timers for harbinger, sealer, anchor-manager.
- **Acceptance:** `systemctl --user status` shows running, with restart on failure.

**Queue env**
```env
REDIS_URL=redis://localhost:6379
HARbINGER_SIG_REQUIRED=1
SEAL_BATCH_MAX_ITEMS=5000
SEAL_BATCH_MAX_INTERVAL_MS=120000
```

---

## Workstream D — Analytics + Ψ‑Field
**Goal:** Visible civilization health, alerting on anomalies, and RBAC.

### D1. Guardian Hardening
- **Task:** Default to advanced mode, enforce telemetry schema & signature.
- **Acceptance:** Unsigned or malformed telemetry rejected; metrics tagged with `node_did`.

### D2. Alerting & Drill‑downs
- **Task:** Emit Prometheus metrics + Alertmanager routes; drill‑down links into receipts & batches.
- **Acceptance:** Alerts fire on low Ψ, seal retry spikes, or anchor verification failures.

### D3. RBAC + OIDC
- **Task:** Add OIDC login (e.g., Keycloak) to Analytics (Next.js) with role map (viewer, operator, admin).
- **Acceptance:** Anonymous access blocked; alerts & drill‑downs gated by role.

---

## Workstream E — Ops & Compliance
**Goal:** Minimal, effective hardening across all services.

- **TLS:** Terminate with Caddy mTLS between internal services.
- **Secrets:** Only mounted as tmpfs; SOPS/age by default.
- **Containers:** `read_only: true`, `no-new-privileges`, `cap_drop: [ALL]`.
- **Audit:** Append only logs; weekly rotate; JSON lines with request IDs.

**Compose snippet (redis + caddy)**
```yaml
version: "3.9"
services:
  redis:
    image: redis:7
    command: ["redis-server", "--appendonly", "yes"]
    ports: ["6379:6379"]
    read_only: true
  caddy:
    image: caddy:2
    volumes:
      - ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
    ports: ["443:443"]
    read_only: true
```

---

## Acceptance Gates (Go/No‑Go)
1. **Federation:** 3‑node lab converges on same root with a forced conflict run.
2. **Anchors:** 10 consecutive anchors verified & receipts persisted; backoff observed on simulated outage.
3. **Sealer:** DLQ remains empty under normal load; retries < 2% of total jobs.
4. **Analytics/Ψ:** Alert fires when Ψ drops below threshold; drill‑down opens exact batch & receipts.
5. **Ops:** All services start via systemd, restart on failure, and expose `/healthz` over TLS.

---

## Weekend Execution Map (Hours are aggressive, pair‑program when possible)
**Friday (evening)**  
- C1 Queue scaffolding + Harbinger signature validation (3h)  
- C3 systemd units templated (1h)

**Saturday**  
- A1/A2 Federation client + DID allowlist (4h)  
- A3/A4 Conflict law + Merkle recompute (3h)  
- B1 SOPS secrets + env plumbing (2h)  
- B2 Backoff orchestrator (2h)

**Sunday**  
- B3 Receipt verification (EVM + BTC) + persistence (4h)  
- D1 Guardian hardening + D2 alert metrics (3h)  
- D3 RBAC (OIDC) wrapper for Analytics (3h)  
- E Ops hardening pass (2h)

> **Total:** ~27 hours (parallelizable)

---

## Command Rituals (Solve et Coagula)
```bash
# Nigredo — Dissolve old triggers
make stop && docker compose -f compose/redis.yaml up -d

# Albedo — Purify queues
node services/harbinger/dist/server.js &
node services/sealer/dist/worker.js &

# Citrinitas — Illuminate anchor truth
systemctl --user enable --now anchor-manager.service anchor-manager.timer

# Rubedo — Fix memory into stone
make anchor-all && scripts/verify-anchor.sh --root $(cat latest-root.txt) --evm --btc
```

---

## Artifacts in this package
- `systemd/*.service|*.timer` — ready to install (user units)
- `compose/redis.yaml` — durable queue baseline
- `config/examples/federation.config.yaml` — federation wiring
- `config/examples/guardian.env` — Ψ‑Field defaults
- `scripts/verify-anchor.sh` — receipt verifier skeleton

**Astra inclinant, sed non obligant — influence acknowledged, sovereignty preserved.**
