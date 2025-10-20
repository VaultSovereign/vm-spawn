# Proposal: Adopt Cryptographic Memory Standard (VaultMesh Remembrancer)

## Summary

Adopt a machine-verifiable memory layer for all DAO governance: every decision, artifact, and deployment will have a GPG signature, RFC 3161 timestamp (dual TSA), and Merkle-audited receipt, with a public receipts index.

**Core Principle:** Blockchain proves *that* we decided; VaultMesh proves *why/how/when*.

---

## What Passes if YES

### 1. Trust Anchor Designation
The DAO designates `REMEMBRANCER_KEY_ID=<multisig_or_steward_key>` as the official memory trust anchor.

### 2. Recording Requirements
All governance artifacts must be recorded with:
```bash
remembrancer record deploy \
  --component dao-governance \
  --version proposal-<N> \
  --sha256 $(sha256sum artifact | awk '{print $1}') \
  --evidence <artifact_path> \
  --chain_ref "eip155:1/tx:0x<proposal_or_tx_hash>"
```

### 3. Cryptographic Attestation
Every recorded artifact must include:
- **GPG signature** (authenticity)
- **Dual RFC 3161 timestamps** (existence proof from two independent TSAs)
- **Merkle audit receipt** (tamper detection)

### 4. Transparency Requirement
The Merkle root and receipts index (`docs/receipts/index.md`) must be updated on every merge to `main`.

---

## Verification Commands

Any DAO member can verify artifacts independently:

### GPG Signature Verification
```bash
gpg --verify dist/genesis.tar.gz.asc dist/genesis.tar.gz
```

### Timestamp Token Inspection
```bash
openssl ts -reply -in dist/genesis.tar.gz.tsr -text
```

### RFC 3161 Verification (Public TSA)
```bash
openssl ts -verify \
  -in dist/genesis.tar.gz.tsr \
  -data dist/genesis.tar.gz \
  -CAfile ops/certs/cache/public.ca.pem \
  -untrusted ops/certs/cache/public.tsa.crt
```

### RFC 3161 Verification (Enterprise TSA)
```bash
openssl ts -verify \
  -in dist/genesis.tar.gz.tsr \
  -data dist/genesis.tar.gz \
  -CAfile ops/certs/cache/enterprise.ca.pem \
  -untrusted ops/certs/cache/enterprise.tsa.crt
```

### Merkle Audit Log Verification
```bash
./ops/bin/remembrancer verify-audit
```

---

## Current State (Genesis v4.1)

**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

**Status:**
- ✅ Four Covenants infrastructure deployed
- ✅ Health checks: 16/16 passing
- ✅ Tests: 10/10 (100%)
- ✅ Federation merge operational
- ✅ Dual-TSA verification ready

**Commits:**
- `a7d97d0` - Four Covenants hardening (31 files)
- `74bc0dc` - Completion documentation

---

## Rationale

### Legal-Grade Proof
- **RFC 3161 timestamps** from two independent Time Stamp Authorities provide court-admissible proof of existence
- **GPG signatures** prove authenticity without requiring centralized CAs
- **Merkle audit logs** detect any tampering with historical records

### DAO Governance Benefits
1. **Provable Context:** Every decision has cryptographic proof of *why/how/when*
2. **Independent Verification:** Any member can verify without trusting intermediaries
3. **Court-Portable:** Receipts include exact verification commands per IETF standards
4. **Fork-Resistant:** Deterministic federation enables future cross-DAO knowledge sharing

### Standards-Based
- **RFC 3161** (IETF Time-Stamp Protocol) - widely recognized legal standard
- **OpenPGP** - battle-tested, sovereign key custody
- **JCS** (JSON Canonicalization Scheme) - deterministic JSON serialization
- **MCP** (Model Context Protocol) - open interop for AI/agent coordination

---

## Implementation Timeline

### Immediate (Upon Approval)
1. Designate DAO operator key as `REMEMBRANCER_KEY_ID`
2. Bootstrap TSA certificates with SPKI pinning
3. Seal Genesis artifact with dual timestamps

### Short-Term (Next 30 Days)
1. Record all active governance proposals with chain refs
2. Generate receipts transparency site
3. Add verification instructions to governance docs

### Ongoing
1. Record every proposal execution with dual timestamps
2. Update Merkle root on every merge to main
3. Publish receipts index for public audit

---

## Cost Analysis

### One-Time Setup
- Operator time: ~2 hours (TSA bootstrap, Genesis seal)
- Infrastructure: $0 (FreeTSA is free; enterprise TSA optional)

### Ongoing Costs
- Per-decision recording: ~5 minutes operator time
- Storage: Negligible (<1KB per receipt)
- TSA costs: $0 (FreeTSA) to ~$50/year (commercial backup)

### Value Delivered
- **Legal defensibility:** Court-portable proof of governance decisions
- **Transparency:** Public, independently verifiable receipts
- **Trust:** Cryptographic proof > verbal commitments

---

## Risk Mitigation

### TSA Outage/Compromise
- **Response:** Timestamp with alternate TSA; annotate receipt; re-verify when primary recovers
- **Mitigation:** Dual-TSA setup (public + enterprise) provides redundancy

### Receipt Tamper Attempt
- **Detection:** Merkle root mismatch raises immediate alert
- **Response:** Deterministic merge with operator-signed MERGE_RECEIPT reconciles state

### Key Compromise
- **Response:** Publish revocation receipt; rotate to new key; re-sign recent receipts
- **Mitigation:** Hardware key custody (YubiKey/HSM) recommended

---

## Success Criteria

This proposal succeeds when:
- ✅ Genesis artifact sealed with dual timestamps
- ✅ First governance proposal recorded with chain ref
- ✅ Receipts index published and accessible
- ✅ At least 3 DAO members verify artifacts independently
- ✅ Merkle root updated on main branch

---

## Verification Instructions for Members

### 1. Clone Repository
```bash
git clone <repo_url>
cd <repo>
```

### 2. Verify Genesis
```bash
# Check GPG signature
gpg --verify dist/genesis.tar.gz.asc dist/genesis.tar.gz

# Check timestamps (both TSAs)
./ops/bin/rfc3161-verify dist/genesis.tar.gz

# Verify audit log
./ops/bin/remembrancer verify-audit
```

### 3. Verify Specific Proposal
```bash
# List all receipts
./ops/bin/remembrancer list deployments

# Verify specific proposal
./ops/bin/remembrancer verify <artifact>
```

---

## Resources

**Documentation:**
- Four Covenants Plan: `four-covenants-hardening.plan.md`
- Federation Semantics: `docs/FEDERATION_SEMANTICS.md`
- Covenant Signing Guide: `docs/COVENANT_SIGNING.md`
- Covenant Timestamps Guide: `docs/COVENANT_TIMESTAMPS.md`

**Receipts:**
- Transparency Index: `docs/receipts/index.md`
- Current Merkle Root: `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

**Infrastructure:**
- Health Check: `./ops/bin/health-check` (16/16 passing)
- Covenant Runner: `make covenant` (validates all four covenants)
- Receipts Generator: `./ops/bin/receipts-site`

---

## Voting Options

- **YES** - Adopt VaultMesh Remembrancer as DAO memory standard
- **NO** - Maintain current governance documentation approach
- **ABSTAIN** - No position

---

## Additional Notes

### Phase I (Current)
- GPG signatures + dual RFC 3161 timestamps
- Merkle audit logs
- Deterministic federation merge (JCS-canonical)
- Machine-readable test oracle

### Phase II (Future)
- SLSA provenance integration
- Dual-rail signatures (GPG + cosign keyless)
- OpenTimestamps blockchain anchoring
- Selective amnesia protocol (redaction with tombstone receipts)

---

**Proposal Status:** Ready for vote  
**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`  
**Infrastructure Status:** ✅ Operational

🜄 **Astra inclinant, sed non obligant. The DAO remains sovereign.**

