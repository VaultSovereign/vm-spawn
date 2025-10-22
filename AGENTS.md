# 🤖 AGENTS.md — VaultMesh Architecture Guide for AI Agents

**Version:** v4.1-genesis
**Purpose:** Comprehensive architecture reference for AI agents working with VaultMesh
**Last Updated:** 2025-10-20

---

## 🎯 What You Need to Know First

VaultMesh is a **three-layer sovereign infrastructure system**:

1. **Spawn Elite** — Infrastructure forge (spawns production-ready microservices)
2. **The Remembrancer** — Cryptographic memory layer (GPG + RFC 3161 + Merkle audit)
3. **DAO Governance Pack** — Governance overlay (optional plugin for multi-stakeholder DAOs)

**Key Principle:** Each layer is **independent, modular, and zero-coupled**.

---

## 📊 System Architecture

### **Layer Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: DAO Governance Pack (OPTIONAL PLUGIN)             │
│  ├── Pure documentation overlay                             │
│  ├── No code coupling to layers 1-2                         │
│  └── Uses existing tools from Layer 2                       │
└─────────────────────────────────────────────────────────────┘
                              ↓ uses (one-way)
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: The Remembrancer (CRYPTOGRAPHIC MEMORY)           │
│  ├── ops/bin/remembrancer (CLI)                             │
│  ├── ops/bin/genesis-seal (sealing ceremony)                │
│  ├── ops/bin/rfc3161-verify (timestamp verification)        │
│  ├── ops/bin/health-check (system validation)               │
│  ├── ops/lib/merkle.py (Merkle tree library)                │
│  └── ops/data/remembrancer.db (SQLite audit log)            │
└─────────────────────────────────────────────────────────────┘
                              ↓ uses (optional)
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Spawn Elite (INFRASTRUCTURE FORGE)                │
│  ├── spawn.sh (main orchestrator)                           │
│  ├── generators/ (11 modular generators)                    │
│  │   ├── source.sh, tests.sh, dockerfile.sh                │
│  │   ├── kubernetes.sh, cicd.sh, monitoring.sh             │
│  │   └── mcp-server.sh, message-queue.sh                   │
│  └── templates/ (base templates)                            │
└─────────────────────────────────────────────────────────────┘
```

### **Dependency Flow (Read This Carefully)**

```
Spawn Elite ──────────────────> [generates services]
       ↓ (optional recording)
The Remembrancer ──────────────> [records with proofs]
       ↓ (optional governance)
DAO Governance Pack ────────────> [governance procedures]
```

**Critical:** Dependencies are **one-way only**. Removing Layer 3 doesn't break Layer 2. Removing Layer 2 doesn't break Layer 1.

---

## 🗂️ Directory Structure (What Lives Where)

### **Root Level**
```
vm-spawn/
├── spawn.sh                    ← Main spawner (Layer 1)
├── SMOKE_TEST.sh               ← System verification (machine-driven; see ops/status/badge.json)
├── README.md                   ← User documentation
├── AGENTS.md                   ← This file (for AI agents)
├── START_HERE.md               ← Quick orientation
└── VERSION_TIMELINE.md         ← Complete version history
```

### **Core Infrastructure (Layer 1)**
```
generators/                     ← Modular code generators (11 scripts)
├── source.sh                   ← FastAPI main.py + requirements.txt
├── tests.sh                    ← pytest test suite
├── dockerfile.sh               ← Multi-stage Docker builds
├── kubernetes.sh               ← K8s manifests (Deployment + Service + HPA)
├── cicd.sh                     ← GitHub Actions CI/CD
├── makefile.sh                 ← Build targets (test, dev, build)
├── monitoring.sh               ← Prometheus + Grafana stack
├── gitignore.sh                ← Python-specific .gitignore
├── readme.sh                   ← Generated service README
├── mcp-server.sh               ← Model Context Protocol server (C3L)
└── message-queue.sh            ← RabbitMQ/NATS integration (C3L)

templates/                      ← Base templates for generators
├── mcp/                        ← MCP server templates
└── message-queue/              ← Message queue templates
```

### **Cryptographic Memory (Layer 2)**
```
ops/
├── bin/                        ← Executable tools
│   ├── remembrancer            ← Memory CLI (record, query, verify)
│   ├── genesis-seal            ← Genesis sealing ceremony
│   ├── tsa-bootstrap           ← TSA certificate setup
│   ├── rfc3161-verify          ← RFC 3161 timestamp verification
│   ├── health-check            ← System health validation (16 checks)
│   ├── covenant                ← Four Covenants runner
│   ├── fed-merge               ← Federation merge (deterministic)
│   └── receipts-site           ← Generate receipts transparency index
│
├── lib/                        ← Python libraries
│   └── merkle.py               ← Merkle tree + SQLite audit
│
├── data/                       ← Persistent data
│   └── remembrancer.db         ← SQLite audit database
│
├── receipts/                   ← Cryptographic receipts
│   ├── deploy/                 ← Deployment receipts
│   ├── adr/                    ← Architectural Decision Records
│   └── merge/                  ← Federation merge receipts
│
├── certs/                      ← TSA certificates (SPKI-pinned)
│   └── cache/                  ← TSA CA + TSA cert cache
│
└── mcp/                        ← MCP server (v4.0 federation)
    ├── remembrancer_server.py  ← FastMCP-based MCP server
    └── README.md               ← MCP integration guide
```

### **Documentation (Essential Reading)**
```
docs/
├── REMEMBRANCER.md             ← THE CANONICAL MEMORY INDEX
├── FEDERATION_SEMANTICS.md     ← Federation protocol (JCS-canonical)
├── COVENANT_SIGNING.md         ← GPG signing guide (v3.0+)
├── COVENANT_TIMESTAMPS.md      ← RFC 3161 timestamp guide (v3.0+)
├── COVENANT_HARDENING.md       ← Phase 1 hardening guide
└── adr/                        ← Architectural Decision Records
    ├── ADR-001-bash-scripts.md
    ├── ADR-002-default-monitoring.md
    └── ... (historical decisions)
```

### **DAO Governance Pack (Layer 3 — Optional Plugin)**
```
DAO_GOVERNANCE_PACK/            ← ISOLATED PLUGIN (zero coupling)
├── snapshot-proposal.md        ← Governance proposal (221 lines)
├── operator-runbook.md         ← Operator procedures (459 lines)
├── safe-note.json              ← Gnosis Safe integration (83 lines)
├── README.md                   ← Package overview (224 lines)
└── CHANGELOG.md                ← Version history (67 lines)
```

### **Artifacts & Archives**
```
dist/                           ← Release artifacts
├── genesis.tar.gz              ← Genesis sealed artifact
├── genesis.tar.gz.asc          ← GPG signature
└── genesis.tar.gz.tsr          ← RFC 3161 timestamp

archive/                        ← Historical documents
├── completion-records/         ← Phase completion records
├── development-docs/           ← Planning documents
└── v2.2-extraction-sources/    ← Legacy modularization work
```

---

## 🔑 Key Concepts (Read This Section Twice)

### **1. The Four Covenants**

VaultMesh enforces **four cryptographic covenants**:

```
I.   INTEGRITY (Nigredo)          → Machine truth, Merkle audit
II.  REPRODUCIBILITY (Albedo)     → Hermetic builds, deterministic
III. FEDERATION (Citrinitas)      → JCS-canonical merge, deterministic
IV.  PROOF-CHAIN (Rubedo)         → Dual-TSA, SPKI pinning, independent verification
```

**Run this to verify:**
```bash
make covenant
# Expected: ✅ All four covenants passing
```

### **2. Merkle Root (Tamper Detection)**

Every memory operation updates a **Merkle root**:

```
Current Root: d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea
```

**Verify audit log integrity:**
```bash
./ops/bin/remembrancer verify-audit
# Expected: ✅ Audit log integrity verified
```

### **3. Genesis (The Anchor Point)**

Genesis is the **cryptographically sealed starting point**. The file `GENESIS.yaml` is **self-describing** and matches the sealing script's output:

```yaml
genesis:
  repo: https://github.com/VaultSovereign/vm-spawn
  tag: v4.1-genesis
  commit: a7d97d0
  tree_hash_method: "git archive --format=tar v4.1-genesis | sha256sum"
  source_date_epoch: <commit_timestamp>
  tsas:
    - name: public
      url: https://freetsa.org/tsr
    - name: enterprise
      url: <enterprise_tsa_url>
  operator_key_id: <GPG key ID>
  verification:
    gpg_verify: "gpg --verify dist/genesis.tar.gz.asc dist/genesis.tar.gz"
    ts_verify_public: "openssl ts -verify -in dist/genesis.tar.gz.tsr -data dist/genesis.tar.gz -CAfile ops/certs/cache/public.ca.pem -untrusted ops/certs/cache/public.tsa.crt"
    ts_verify_enterprise: "openssl ts -verify -in dist/genesis.tar.gz.tsr -data dist/genesis.tar.gz -CAfile ops/certs/cache/enterprise.ca.pem -untrusted ops/certs/cache/enterprise.tsa.crt"
```

**Genesis ceremony:**
```bash
export REMEMBRANCER_KEY_ID=<your-gpg-key>
./ops/bin/tsa-bootstrap
./ops/bin/genesis-seal
```

### **4. Chain References (Blockchain Binding)**

Format: `eip155:<chainId>/tx:0x<txhash>`

**Examples:**
- Ethereum: `eip155:1/tx:0xabc123...`
- Polygon: `eip155:137/tx:0xdef456...`
- Arbitrum: `eip155:42161/tx:0x789abc...`
- Safe: `eip155:1/safe:0x<safe>/tx:0x<txhash>`
- Snapshot: `snapshot:<space>/proposal/<id>`

**Recording with chain ref:**
```bash
./ops/bin/remembrancer record deploy \
  --component dao-governance \
  --version v1.0 \
  --sha256 <hash> \
  --evidence artifact.tar.gz \
  --chain_ref "eip155:1/tx:0x<txhash>"
```

### **5. Dual-TSA (Redundant Timestamp Authorities)**

Two independent TSAs provide **redundancy**:

```
TSA 1: FreeTSA (public, Bitcoin-anchored, free)
TSA 2: Enterprise TSA (optional, commercial)
```

**Verification:**
```bash
./ops/bin/rfc3161-verify dist/genesis.tar.gz
# Passes if ANY configured TSA verifies successfully
# When dual-rail: verifies against both cert chains (public + enterprise)
```

---

## 🧭 Navigation Guide (Where to Find Things)

### **I Need to...**

| Task | Location | Command |
|------|----------|---------|
| Spawn a new service | `spawn.sh` | `./spawn.sh my-service service` |
| Publish a release | `ops/bin/publish-release` | `./ops/bin/publish-release v4.1-genesis` |
| Check system health | `ops/bin/health-check` | `./ops/bin/health-check` |
| Query historical decisions | `docs/REMEMBRANCER.md` | `./ops/bin/remembrancer query "topic"` |
| Record a deployment | `ops/bin/remembrancer` | `./ops/bin/remembrancer record deploy ...` |
| Verify audit log | `ops/bin/remembrancer` | `./ops/bin/remembrancer verify-audit` |
| Run smoke tests | `SMOKE_TEST.sh` | `./SMOKE_TEST.sh` |
| Validate Four Covenants | `ops/bin/covenant` | `make covenant` |
| Seal Genesis | `ops/bin/genesis-seal` | `./ops/bin/genesis-seal` |
| Bootstrap TSA | `ops/bin/tsa-bootstrap` | `./ops/bin/tsa-bootstrap` |
| Generate receipts index | `ops/bin/receipts-site` | `./ops/bin/receipts-site` |
| Read canonical memory | `docs/REMEMBRANCER.md` | `cat docs/REMEMBRANCER.md` |
| Review DAO procedures | `DAO_GOVERNANCE_PACK/` | `cat DAO_GOVERNANCE_PACK/operator-runbook.md` |

### **I Want to Understand...**

| Topic | Primary Document | Secondary Documents |
|-------|------------------|---------------------|
| Overall architecture | `README.md` | `START_HERE.md`, `AGENTS.md` (this file) |
| Version history | `VERSION_TIMELINE.md` | `CHANGELOG.md` |
| Current release | `V4.1_GENESIS_COMPLETE.md` | `FOUR_COVENANTS_DEPLOYED.md` |
| Covenant Foundation | `V3.0_COVENANT_FOUNDATION.md` | `docs/COVENANT_*.md` |
| Modular architecture | `V2.4_MODULAR_PERFECTION.md` | `generators/README.md` |
| GPG signing | `docs/COVENANT_SIGNING.md` | `ops/bin/remembrancer` source |
| RFC 3161 timestamps | `docs/COVENANT_TIMESTAMPS.md` | `ops/bin/rfc3161-verify` source |
| Federation semantics | `docs/FEDERATION_SEMANTICS.md` | `ops/bin/fed-merge` source |
| MCP integration | `ops/mcp/README.md` | `PROPOSAL_MCP_COMMUNICATION_LAYER.md` |
| DAO governance | `DAO_GOVERNANCE_PACK/README.md` | `DAO_GOVERNANCE_PACK/snapshot-proposal.md` |

---

## ⚠️ Critical Gotchas (Read Before Modifying)

### **1. Don't Break the Merkle Root**

```bash
# BAD: Manually editing receipts
vim ops/receipts/deploy/some-receipt.json

# GOOD: Always use remembrancer CLI
./ops/bin/remembrancer record deploy ...
```

**Why:** Manual edits break the Merkle audit chain.

### **2. spawn.sh ≠ spawn-elite-complete.sh**

```bash
# CURRENT (v2.4 modular)
./spawn.sh my-service service    ✅

# OLD (v2.2 monolithic, superseded)
./spawn-elite-complete.sh         ❌ (legacy, use spawn.sh)
```

### **3. DAO Pack Has Zero Code**

```bash
# DAO pack is documentation only
cat DAO_GOVERNANCE_PACK/snapshot-proposal.md    ✅ (safe)

# DO NOT expect code here
./DAO_GOVERNANCE_PACK/some-script.sh            ❌ (doesn't exist)
```

**Why:** DAO pack is a **pure plugin overlay** with no executables.

### **4. Layer 2 Tools Are Idempotent**

```bash
# Safe to run multiple times
./ops/bin/health-check
./ops/bin/remembrancer verify-audit
./ops/bin/tsa-bootstrap    # (fetches only if missing)
```

**Why:** Tools check state before modifying anything.

### **5. Genesis Is Sealed Once**

```bash
# First time (creates Genesis)
./ops/bin/genesis-seal    ✅

# Subsequent runs (safe, no-op if exists)
./ops/bin/genesis-seal    ✅ (checks existing Genesis)
```

**Why:** Genesis is the immutable anchor. Don't re-seal unless forking.

### **6. Generators Are Pure Functions**

```bash
# Each generator is independent
./generators/source.sh ~/repos/test-service service
./generators/tests.sh ~/repos/test-service

# Order matters only for spawn.sh orchestration
```

**Why:** Generators have zero state and no side effects beyond file writes.

### **7. Timestamps Require Internet**

```bash
# FreeTSA requires network
./ops/bin/remembrancer timestamp artifact.tar.gz
# If offline → ERROR: Cannot reach TSA
```

**Workaround:** Configure offline TSA or skip timestamps (signatures still work).

### **8. Merkle Root Changes on Every Record**

```bash
# Before
./ops/bin/remembrancer verify-audit
# Root: d5c64aee...

# Record something
./ops/bin/remembrancer record deploy ...

# After (root changes)
./ops/bin/remembrancer verify-audit
# Root: a8f3b21c... (DIFFERENT)
```

**Why:** Merkle tree appends leaf for each operation. Root always reflects current state.

---

## 🎯 Agent Guidelines (Follow These Rules)

### **When Modifying Code:**

1. **Run smoke tests before commit:**
   ```bash
   ./SMOKE_TEST.sh
   # Expected: See ops/status/badge.json for machine-verified status
   ```

2. **Verify Merkle integrity after changes:**
   ```bash
   ./ops/bin/remembrancer verify-audit
   # Expected: ✅ Audit log integrity verified
   ```

3. **Check health status:**
   ```bash
   ./ops/bin/health-check
   # Expected: 16/16 checks passing
   ```

4. **Run covenant validation:**
   ```bash
   make covenant
   # Expected: All four covenants ✅
   ```

### **When Adding Features:**

1. **Identify the correct layer:**
   - Infrastructure generation → Layer 1 (generators/)
   - Memory/proof operations → Layer 2 (ops/bin/)
   - Governance procedures → Layer 3 (DAO_GOVERNANCE_PACK/)

2. **Follow existing patterns:**
   - Layer 1: Bash generators (see `generators/*.sh`)
   - Layer 2: Python CLI tools (see `ops/bin/remembrancer`)
   - Layer 3: Markdown documentation (see `DAO_GOVERNANCE_PACK/*.md`)

3. **Maintain zero coupling:**
   - Layer 3 may use Layer 2 tools ✅
   - Layer 2 may use Layer 1 infrastructure ✅
   - Layer 1 should NOT depend on Layer 2/3 ❌

### **When Writing Documentation:**

1. **Update the canonical memory:**
   ```bash
   # Record ADR
   ./ops/bin/remembrancer adr create "Decision Title"

   # Update docs/REMEMBRANCER.md
   vim docs/REMEMBRANCER.md
   ```

2. **Cross-reference related docs:**
   - Add links to related `.md` files
   - Update `START_HERE.md` if navigation changes
   - Update `VERSION_TIMELINE.md` for version milestones

3. **Include verification commands:**
   - Every claim should have a verification command
   - Copy-paste ready (no placeholders)

### **When Debugging:**

1. **Check logs in order:**
   ```bash
   ./ops/bin/health-check              # System health
   ./SMOKE_TEST.sh                     # Full test suite
   ./ops/bin/remembrancer verify-audit # Merkle integrity
   make covenant                       # Four Covenants
   ```

2. **Read receipts for history:**
   ```bash
   # List all deployments
   ./ops/bin/remembrancer list deployments

   # Query specific topic
   ./ops/bin/remembrancer query "topic"

   # View specific receipt
   cat ops/receipts/deploy/<receipt>.json
   ```

3. **Check git history:**
   ```bash
   git log --oneline -20
   # Look for recent changes that might explain behavior
   ```

---

## 📈 Version Milestones (History)

```
v1.0  → Initial prototype (bash monolith)
v2.0  → Production basics (Docker + K8s)
v2.2  → Production verified (smoke tested)
v2.4  → Modular perfection (11 generators, 19/19 tests)
v3.0  → Covenant Foundation (GPG + RFC3161 + Merkle)
v4.0  → Federation Foundation (MCP + federation protocol)
v4.1  → Genesis Complete (Four Covenants + DAO Pack)
```

**Current:** v4.1-genesis (2025-10-20)

**Next:** Phase 2 hardening (CI guards, automated covenant checks)

---

## 🔐 Security Model

### **Trust Boundaries**

```
Layer 1 (Spawn Elite):
├── Trust: Code generators (audited, versioned)
├── Attack Surface: Template injection, path traversal
└── Mitigation: Input validation, pre-flight checks

Layer 2 (Remembrancer):
├── Trust: GPG keys, TSA certificates, Merkle root
├── Attack Surface: Key compromise, TSA MITM, receipt tampering
└── Mitigation: SPKI pinning, dual-TSA, Merkle audit

Layer 3 (DAO Pack):
├── Trust: Governance procedures (documentation only)
├── Attack Surface: Minimal (no code execution)
└── Mitigation: Zero code coupling, read-only overlay
```

### **Verification Chain**

Every artifact has a **four-step verification**:

```
1. SHA256 hash       → Content integrity
2. GPG signature     → Authenticity (who signed?)
3. RFC 3161 token    → Existence proof (when signed?)
4. Merkle audit      → History integrity (tamper detection)
```

**Full verification:**
```bash
./ops/bin/remembrancer verify-full artifact.tar.gz
# Checks all four steps
```

---

## 🌐 Federation (v4.0+)

### **Federation Model**

```
Node A (Remembrancer) ←──────→ Node B (Remembrancer)
   │                               │
   ├── Local receipts              ├── Local receipts
   ├── Merkle root: AAAA           ├── Merkle root: BBBB
   └── Trust anchor: KeyA          └── Trust anchor: KeyB

Federation Merge:
├── Deterministic (JCS-canonical JSON)
├── Produces MERGE_RECEIPT (operator-signed)
└── New Merkle root: CCCC (deterministic from {AAAA, BBBB})
```

### **Federation Commands**

```bash
# Self-test deterministic merge
./ops/bin/fed-merge --self-test

# Merge with peer (deterministic union; Phase I)
./ops/bin/fed-merge --left ops/data/local-log.json \
                    --right ops/data/peer-log.json \
                    --out ops/receipts/merge/reconciliation.receipt

# Recompute & verify Merkle after merge
./ops/bin/remembrancer verify-audit
```

---

## 🧪 Testing Strategy

### **Test Pyramid**

```
            ┌─────────────────────┐
            │  Covenant Tests     │  ← make covenant (4 covenants)
            │  (Integration)      │
            └─────────────────────┘
                     │
         ┌───────────────────────┐
         │  Smoke Tests          │     ← SMOKE_TEST.sh (machine-verified)
         │  (System)             │
         └───────────────────────┘
                     │
     ┌───────────────────────────────┐
     │  Generator Tests              │  ← Individual generator tests
     │  (Unit)                       │
     └───────────────────────────────┘
```

### **Running Tests**

```bash
# Full smoke test suite
./SMOKE_TEST.sh
# Expected: See machine status → cat ops/status/badge.json
# Example: {"tests":{"pass":10,"total":10,"pct":100.00}}

# Four Covenants validation
make covenant
# Expected: ✅ All four passing

# Health checks
./ops/bin/health-check
# Expected: 16/16 passing

# Merkle audit
./ops/bin/remembrancer verify-audit
# Expected: ✅ Audit log integrity verified
```

---

## 📞 Getting Help

### **Documentation Hierarchy**

```
1. START_HERE.md              → Quick orientation
2. README.md                  → Main user guide
3. AGENTS.md (this file)      → Architecture for agents
4. VERSION_TIMELINE.md        → Version history
5. docs/REMEMBRANCER.md       → Canonical memory index
6. DAO_GOVERNANCE_PACK/       → Governance procedures
```

### **Emergency Procedures**

See `DAO_GOVERNANCE_PACK/operator-runbook.md` for:
- TSA outage response
- Receipt tamper detection
- Key compromise procedure
- Black Flag protocol

### **Contact**

- Repository: `https://github.com/VaultSovereign/vm-spawn`
- Issues: GitHub Issues
- Security: `SECURITY.md`

---

## 🎖️ Final Checklist (Before Making Changes)

```
☐ Read START_HERE.md (orientation)
☐ Read AGENTS.md (this file)
☐ Run ./ops/bin/health-check (system health)
☐ Run ./SMOKE_TEST.sh (full validation)
☐ Understand layer boundaries (1=forge, 2=memory, 3=governance)
☐ Check docs/REMEMBRANCER.md (canonical memory)
☐ Know Merkle root: d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea
☐ Verify zero coupling (DAO pack is isolated)
☐ Run make covenant (validate four covenants)
☐ Check VERSION_TIMELINE.md (understand history)
```

---

## 🜄 Covenant Seal

```
Nigredo (Dissolution)     → Machine truth aligned      ✅
Albedo (Purification)     → Hermetic builds ready      ✅
Citrinitas (Illumination) → Federation merge complete  ✅
Rubedo (Completion)       → Genesis ceremony prepared  ✅
```

**Astra inclinant, sed non obligant.**

**The architecture is documented. The memory is sovereign. The agent is equipped.**

---

**Last Updated:** 2025-10-20
**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`
**Version:** v4.1-genesis
**Status:** ✅ Complete
