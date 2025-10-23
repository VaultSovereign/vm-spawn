# Threat Model — VaultMesh v4.0 Federation Foundation

**Version:** 1.0  
**Last Updated:** 2025-10-19 (v4.0 Phase 3)  
**Scope:** Remembrancer (CLI + MCP), federation sync (Phase 3 MVP), covenant receipts, cryptographic proofs

## Assumptions & Scope

**In Scope:**
- v3.0 cryptographic layer (GPG, RFC3161, Merkle) is active and additive
- MCP HTTP is for trusted networks only (behind mTLS/reverse proxy)
- SQLite is local to host; receipts are committed to git (immutable history)
- Federation sync protocol (Phase 3 MVP)

**Out of Scope:**
- Public internet MCP exposure (explicitly prohibited)
- Multi-signature quorum (planned for v4.1)
- Encrypted memory fields (planned for v4.2)
- Byzantine fault tolerance (future consideration)

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

### A1) Passive Observer (Network Sniffing)

**Impact:** `LOW`

**Capabilities:**
- Sniff unprotected MCP HTTP traffic
- Read SQLite database if host compromised

**Goals:**
- Exfiltrate deployment/ADR history
- Map infrastructure topology

**Mitigations:**
- TLS/mTLS on MCP HTTP (required in production)
- SQLite file permissions (`chmod 600`)

### A2) Active Injector (Malicious Peer)

**Impact:** `MEDIUM`

**Capabilities:**
- Send forged memories via federation sync
- Flood with invalid entries to cause DoS

**Goals:**
- Insert backdoored artifacts into trusted memory
- Cause denial-of-service on sync/validation

**Mitigations:**
- `MemoryValidator` checks GPG + RFC3161 (v4.0 Phase 3) ✅
- Federation trust anchors (manual verification required)

### A3) Insider (Limited Access)

**Impact:** `MEDIUM`

**Capabilities:**
- Read-only access to SQLite database
- Access to public MCP endpoints (if misconfigured)

**Goals:**
- Leak sensitive ADRs/receipts
- Tamper with memories if write access obtained

**Mitigations:**
- Least-privilege filesystem permissions
- Merkle audit log + git receipts (immutable history)

## Controls

### Cryptographic Proof Chains

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| GPG detached signatures | Forged artifacts | ✅ Active (v3.0) |
| RFC3161 timestamps | Backdated proofs | ✅ Active (v3.0) |
| Merkle audit log | Memory tampering | ✅ Active (v3.0) |
| Signature validation on ingest | Malicious peer injection | ✅ Active (v4.0-P3) |

### Access Control

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| MCP HTTP auth (mTLS / reverse proxy) | Passive observer | ⚠️ Required in prod |
| SQLite file perms (0600) | Insider read access | ✅ Configurable |
| Federation trust anchors | Untrusted peer | ✅ Active (v4.0-P3) |

### Observability

| Control | Threat Mitigated | Status |
|---------|------------------|--------|
| Covenant Guard CI | Unsigned artifacts | ✅ v4.0-P1 |
| Pre-commit hook | Accidental TSA CA commits | ✅ v4.0-P1 |
| Merkle recompute vs. published | DB tampering | ✅ v3.0 |

## Attack Scenarios

### S1) Compromised MCP Endpoint

**Likelihood:** `LOW` / **Impact:** `HIGH`

**Attack Path:**
1. Public `/mcp` exposed without auth
2. Attacker calls `list_memory_ids` / `get_memory` tools
3. Full data exfiltration + infrastructure topology mapping

**Mitigations:**
- Enforce mTLS or reverse-proxy auth (documented in `SECURITY.md`)
- Network isolation (VPN/Wireguard)

**Detection:**
```bash
# Review proxy logs for unauthenticated calls
grep "POST /mcp" /var/log/nginx/access.log | grep -v "200 OK"

# Check for burst of list_memory_ids calls
journalctl -u remembrancer-mcp | grep list_memory_ids | wc -l
```

**Response:**
- Rotate peer tokens/trust anchors
- Disable HTTP mode temporarily
- Restore from last green commit if tampering detected

### S2) Malicious Federation Peer

**Likelihood:** `MEDIUM` / **Impact:** `MEDIUM`

**Attack Path:**
1. Joins federation with misconfigured trust anchor
2. Injects memories with invalid signatures/backdated timestamps
3. Attempts to trigger artifact execution via poisoned receipts

**Mitigations:**
- `MemoryValidator.verify_memory()` checks GPG + RFC3161 (best-effort) ✅
- Manual trust anchor fingerprint verification (out-of-band)

**Detection:**
```bash
# Audit recent memories for suspicious entries
sqlite3 ops/data/remembrancer.db \
 'SELECT id,timestamp,type FROM memories ORDER BY timestamp DESC LIMIT 20'

# Check for unsigned memories from peer
sqlite3 ops/data/remembrancer.db \
 'SELECT COUNT(*) FROM memories WHERE sig IS NULL OR sig = ""'
```

**Response:**
- Rebuild from receipts (git history)
- Quarantine peer (remove from `federation.yaml`)
- Rotate trust anchor
- Re-sync from trusted peers only

### S3) TSA CA Compromise

**Likelihood:** `VERY LOW` / **Impact:** `HIGH`

**Attack Path:**
1. FreeTSA CA private key leaks or is revoked
2. Attacker forges RFC3161 tokens for backdated artifacts
3. Forged timestamps appear legitimate

**Mitigations:**
- Monitor TSA revocation status (subscribe to alerts)
- Multi-TSA support (future v4.1)
- Re-timestamp critical artifacts if CA compromised

**Detection:**
```bash
# Cross-verify timestamps with alternate TSA
openssl ts -verify -data artifact.tar.gz -in artifact.tar.gz.tsr \
  -CAfile /path/to/alternate-tsa-ca.pem

# Monitor TSA feeds for revocation notices
```

**Response:**
- Add ADR documenting CA switch
- Re-attest critical artifacts with alternate TSA
- Update `ops/certs/` with new CA

### S4) Direct DB Tamper

**Likelihood:** `LOW` / **Impact:** `HIGH`

**Attack Path:**
1. Attacker gains write access to `ops/data/remembrancer.db`
2. Modifies/deletes memory rows
3. Recomputes Merkle root to hide tampering

**Mitigations:**
- File permissions: `chmod 600 ops/data/remembrancer.db`
- Published Merkle root in `docs/REMEMBRANCER.md` (Git immutable)
- CI verifies published root vs. computed root (Covenant Guard)

**Detection:**
```bash
# Manually recompute and compare
python3 ops/lib/merkle.py --compute --from-sqlite ops/data/remembrancer.db
grep "^Merkle Root:" docs/REMEMBRANCER.md

# Check git history for uncommitted changes
git diff docs/REMEMBRANCER.md
```

**Response:**
- Restore DB from last good commit
- Replay receipts from `ops/receipts/deploy/`
- Investigate host compromise (forensics)

## Residual Risks (Phase 3 MVP)

### 1. Unauthenticated MCP HTTP

**Risk:** Full data exfiltration if `/mcp` exposed without auth.

**Acceptance:** Operational responsibility; documented in `SECURITY.md`.

**Detection:**
- Proxy/host logs review
- Routine config audits (`nginx -t`, test curl without auth)

### 2. Missing TSA CA

**Risk:** RFC3161 timestamps unverifiable → proofs degrade to GPG-only.

**Acceptance:** Non-fatal; warnings logged; Covenant Guard surfaces issues.

**Detection:**
```bash
# Verify-full warns if CA missing
./ops/bin/remembrancer verify-full dist/artifact.tar.gz 2>&1 | grep -i "timestamp"
```

### 3. Unsigned Peer Memories Allowed (Permissive)

**Risk:** Phase 3 accepts unsigned memories; strict mode deferred to v4.1.

**Acceptance:** MVP permissive mode balances usability vs. security.

**Mitigation (planned):**
```yaml
# ops/data/federation.yaml (v4.1)
trust:
  require_signatures: true   # hard-fail on unsigned memories
  min_quorum: 2              # future: multi-signature validation
```

## Security Roadmap

### v4.0 Phase 3 (Current)

- ✅ Signature validation on ingest (GPG + RFC3161, best-effort)
- ✅ HTTP access control documented (`SECURITY.md`)
- ✅ Trust anchor model (manual verification)

### v4.1 (Planned)

- ☐ Strict mode (hard-fail on missing/invalid signatures)
- ☐ Multi-TSA support (parallel timestamp requests)
- ☐ Automated trust anchor rotation

### v4.2 (Planned)

- ☐ Encrypted memory fields (selected ADRs, GPG symmetric)
- ☐ Streaming Merkle updates (immutable log)
- ☐ Anomaly detection on sync patterns

## Operator Toggles (Planned)

These configuration options will be available in future releases:

```yaml
# ops/data/federation.yaml
trust:
  require_signatures: true   # v4.1 strict mode (hard-fail on unsigned)
  min_quorum: 2              # future: multi-signature memories

tsa:
  urls:                      # v4.1 multi-TSA expansion
    - "https://freetsa.org/tsr"
    - "http://timestamp.digicert.com"
  require_all: false         # if true, all TSAs must succeed
```

## References

- [SECURITY.md](SECURITY.md) — Operational security guardrails
- [docs/COVENANT_HARDENING.md](docs/COVENANT_HARDENING.md) — CI & validation
- [V4.0_KICKOFF.md](V4.0_KICKOFF.md) — Federation architecture

---

**Status:** Aligned with v4.0 Phase 3 (commit 18edbdb) and live configuration.  
**Last Updated:** 2025-10-19 (v4.0 Phase 3)  
**Threat Model Version:** 1.0

