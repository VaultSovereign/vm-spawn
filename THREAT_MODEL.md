# Threat Model — VaultMesh v4.0 Federation Foundation

## Assets

### Primary

- **Covenant memories:** SQLite database (`ops/data/remembrancer.db`)
- **Merkle roots:** Cryptographic audit log integrity anchors
- **Deployment receipts:** YAML files in `ops/receipts/deploy/`
- **Artifacts:** Signed tarballs, binaries in `dist/`

### Cryptographic Material

- **GPG signatures:** Detached `.asc` files proving artifact authenticity
- **RFC3161 tokens:** `.tsr` files proving timestamp existence
- **TSA CA certificates:** `ops/certs/*.pem` (trust anchors for timestamp verification)
- **Federation trust anchors:** Peer public keys for memory validation

## Adversaries

### 1. Passive Observer (Network Sniffing)

**Capabilities:**
- Monitor unencrypted MCP HTTP traffic
- Read SQLite database if host compromised

**Goals:**
- Exfiltrate deployment history and architectural decisions
- Map infrastructure topology via ADRs

**Impact:** `LOW` (if MCP HTTP uses TLS/mTLS; SQLite has file permissions)

### 2. Active Injector (Malicious Peer)

**Capabilities:**
- Send forged memories via federation sync
- Attempt to poison Merkle tree with invalid signatures

**Goals:**
- Insert backdoored artifacts into trusted memory
- Cause denial-of-service by flooding with invalid memories

**Impact:** `MEDIUM` (mitigated by signature validation in Phase 3)

### 3. Insider with Limited Access

**Capabilities:**
- Read-only access to SQLite database
- Access to public MCP endpoints (if misconfigured)

**Goals:**
- Leak sensitive ADRs or deployment receipts
- Tamper with memories if write access gained

**Impact:** `MEDIUM` (mitigated by file permissions, audit logs)

## Controls

### Cryptographic Proof Chains

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| **GPG Detached Signatures** | Forged artifacts | ✅ Active (v3.0) |
| **RFC3161 Timestamps** | Backdated proofs | ✅ Active (v3.0) |
| **Merkle Audit Log** | Tampered memories | ✅ Active (v3.0) |
| **Signature Validation** | Malicious peer injection | ✅ Active (v4.0 Phase 3) |

### Access Control

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| **MCP HTTP auth (mTLS/proxy)** | Passive observer | ⚠️ Required in prod |
| **SQLite file permissions (0600)** | Insider read access | ✅ Configurable |
| **Federation trust anchors** | Malicious peer | ✅ Active (v4.0 Phase 3) |

### Observability

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| **Covenant Guard CI** | Unsigned artifacts in VCS | ✅ Active (v4.0 Phase 1) |
| **Pre-commit hooks** | Accidental TSA CA commits | ✅ Active (v4.0 Phase 1) |
| **Merkle root recompute** | Database tampering | ✅ Active (v3.0) |

## Attack Scenarios

### Scenario 1: Compromised MCP Endpoint

**Attack Path:**
1. Attacker discovers unsecured `/mcp` endpoint (misconfigured)
2. Calls `list_memory_ids` and `get_memory` tools to exfiltrate data
3. Maps deployment history and infrastructure topology

**Likelihood:** `LOW` (requires misconfiguration)  
**Impact:** `HIGH` (full data exfiltration)

**Mitigations:**
- Enforce mTLS or reverse proxy auth (documented in `SECURITY.md`)
- Monitor `/mcp` access logs for anomalous patterns
- Network isolation (VPN/Wireguard) for federation

### Scenario 2: Malicious Federation Peer

**Attack Path:**
1. Attacker joins federation with forged node credentials
2. Injects memories with invalid signatures or backdated timestamps
3. Attempts to trigger artifact execution via poisoned receipts

**Likelihood:** `MEDIUM` (requires trust anchor misconfiguration)  
**Impact:** `MEDIUM` (caught by signature validation)

**Mitigations:**
- `MemoryValidator.verify_memory()` checks GPG + RFC3161 (v4.0 Phase 3) ✅
- Manual trust anchor verification (out-of-band fingerprint check)
- Audit synced memories: `sqlite3 ops/data/remembrancer.db "SELECT * FROM memories ORDER BY timestamp DESC LIMIT 10"`

### Scenario 3: TSA CA Certificate Compromise

**Attack Path:**
1. FreeTSA CA private key leaks or is revoked
2. Attacker can forge RFC3161 timestamps for artifacts
3. Backdated proofs appear legitimate

**Likelihood:** `VERY LOW` (requires CA compromise)  
**Impact:** `HIGH` (proof chain broken)

**Mitigations:**
- Monitor TSA status (subscribe to FreeTSA alerts)
- Use multiple TSAs for critical artifacts (future enhancement)
- Re-timestamp artifacts with alternate TSA if CA revoked
- Document CA switch in ADR

### Scenario 4: Database Tamper (Direct SQLite Edit)

**Attack Path:**
1. Attacker gains write access to `ops/data/remembrancer.db`
2. Modifies memory rows or deletes entries
3. Recomputes Merkle root to match

**Likelihood:** `LOW` (requires host compromise)  
**Impact:** `HIGH` (memory loss, audit trail broken)

**Mitigations:**
- File permissions: `chmod 600 ops/data/remembrancer.db`
- Merkle root published in `docs/REMEMBRANCER.md` (Git history is immutable)
- CI verifies published root vs. computed root (Covenant Guard)
- Recovery: restore DB from last good commit + receipts

## Residual Risks

### 1. Misconfigured HTTP MCP (No Auth)

**Risk:** MCP endpoint exposed without authentication allows full data exfiltration.

**Acceptance Criteria:** Document in `SECURITY.md`; operator responsibility.

**Detection:** Audit nginx/Caddy config; monitor access logs for unauthenticated requests.

### 2. Missing TSA CA in Production

**Risk:** RFC3161 timestamps not verifiable if `FREETSA_CA` absent; proofs degrade to GPG-only.

**Acceptance Criteria:** Non-fatal; system warns but continues (permissive mode).

**Detection:** `remembrancer verify-full` emits warning; Covenant Guard logs it.

### 3. Unverified Peer Memories (Unsigned)

**Risk:** If peer sends memories without signatures, validator accepts them (permissive mode in v4.0).

**Acceptance Criteria:** Phase 3 MVP; strict mode deferred to v4.1.

**Mitigation:** Operators can enable `require_signatures: true` in `federation.yaml` (future).

## Security Roadmap

### v4.0 Phase 3 (Current)

- [x] Signature validation (GPG + RFC3161) in `MemoryValidator`
- [x] MCP HTTP access control documentation
- [x] Federation trust anchor model

### v4.1 (Future)

- [ ] Strict validation mode (hard-fail on missing signatures)
- [ ] Multi-TSA support (parallel timestamp requests)
- [ ] Automated trust anchor rotation

### v4.2 (Future)

- [ ] Encrypted memory fields (GPG symmetric encryption for sensitive ADRs)
- [ ] Audit log streaming (send Merkle root updates to immutable log)
- [ ] Intrusion detection (anomaly detection on sync patterns)

## References

- [SECURITY.md](SECURITY.md) — Operational security guidelines
- [docs/COVENANT_HARDENING.md](docs/COVENANT_HARDENING.md) — CI and validation
- [V4.0_KICKOFF.md](V4.0_KICKOFF.md) — Federation architecture

---

**Last Updated:** 2025-10-19 (v4.0 Phase 3)  
**Threat Model Version:** 1.0

