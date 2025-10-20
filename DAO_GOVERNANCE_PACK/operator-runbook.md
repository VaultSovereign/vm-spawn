# DAO Operator Runbook — VaultMesh Remembrancer

**Version:** v4.1-genesis  
**Status:** Production Ready  
**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

---

## Table of Contents

1. [One-Time Setup](#one-time-setup)
2. [Daily Operations](#daily-operations)
3. [Recording Governance Decisions](#recording-governance-decisions)
4. [Emergency Procedures](#emergency-procedures)
5. [Verification Commands](#verification-commands)
6. [Troubleshooting](#troubleshooting)

---

## One-Time Setup

### 1. Bootstrap TSA Certificates

```bash
# Set FreeTSA endpoints (public TSA)
export REMEMBRANCER_TSA_URL_1="https://freetsa.org/tsr"
export REMEMBRANCER_TSA_CA_CERT_1="https://freetsa.org/files/cacert.pem"
export REMEMBRANCER_TSA_CERT_1="https://freetsa.org/files/tsa.crt"

# Optional: Set enterprise TSA for redundancy
export REMEMBRANCER_TSA_URL_2="<enterprise_tsa_url>"
export REMEMBRANCER_TSA_CA_CERT_2="<enterprise_ca_url>"
export REMEMBRANCER_TSA_CERT_2="<enterprise_tsa_url>"

# Optional: Set SPKI pins (recommended for production)
export REMEMBRANCER_TSA1_CA_PIN_B64="<computed_pin>"
export REMEMBRANCER_TSA1_TSA_PIN_B64="<computed_pin>"
export REMEMBRANCER_TSA2_CA_PIN_B64="<computed_pin>"
export REMEMBRANCER_TSA2_TSA_PIN_B64="<computed_pin>"

# Fetch and pin TSA certificates
./ops/bin/tsa-bootstrap
```

**Expected Output:**
```
→ Public TSA (if configured)…
✅ SPKI pin OK for public CA
✅ SPKI pin OK for public TSA
→ Enterprise TSA (if configured)…
✅ TSA bootstrap complete → /path/to/ops/certs/cache
```

### 2. Set Operator Key

```bash
# List available GPG keys
gpg --list-secret-keys --keyid-format=long

# Set DAO operator key (multisig or steward key)
export REMEMBRANCER_KEY_ID="<DAO_GPG_KEY_ID>"

# Verify key is available
gpg --list-keys $REMEMBRANCER_KEY_ID
```

### 3. Seal Genesis (First Time Only)

```bash
# Execute Genesis ceremony
./ops/bin/genesis-seal

# This creates:
# - GENESIS (repo tree hash)
# - GENESIS.yaml (self-describing metadata)
# - dist/genesis.tar.gz (sealed artifact)
# - dist/genesis.tar.gz.asc (GPG signature)
# - dist/genesis.tar.gz.tsr (RFC 3161 timestamps)

# Verify dual-rail
./ops/bin/rfc3161-verify dist/genesis.tar.gz
```

### 4. Generate Receipts Index

```bash
# Create public transparency site
./ops/bin/receipts-site

# Review output
cat docs/receipts/index.md
```

---

## Daily Operations

### Health Check

Run before any major operation:

```bash
./ops/bin/health-check
```

**Expected:** 16/16 checks passing

### Covenant Validation

Run to ensure system integrity:

```bash
make covenant
```

**Expected:**
- ✅ Covenant I (Integrity): Tests consistent, Merkle verified
- ✅ Covenant II (Reproducibility): Build deterministic
- ✅ Covenant III (Federation): Merge self-test passed
- ✅ Covenant IV (Proof-chain): Dual-TSA verification passed

---

## Recording Governance Decisions

### Standard Recording Flow

```bash
# 1. Wait for proposal to execute on-chain
# Note the transaction hash or Safe execution hash

# 2. Prepare artifact (if applicable)
# Example: proposal text, contract bytecode, config file

# 3. Record with chain reference
remembrancer record deploy \
  --component dao-governance \
  --version proposal-<N> \
  --sha256 $(sha256sum path/to/artifact | awk '{print $1}') \
  --evidence path/to/artifact \
  --chain_ref "eip155:1/tx:0x<proposal_or_tx_hash>"

# 4. Sign the artifact
remembrancer sign path/to/artifact --key $REMEMBRANCER_KEY_ID

# 5. Timestamp with both TSAs
remembrancer timestamp path/to/artifact

# If enterprise TSA configured:
REMEMBRANCER_TSA_URL=$REMEMBRANCER_TSA_URL_2 remembrancer timestamp path/to/artifact

# 6. Verify full chain
remembrancer verify-full path/to/artifact

# 7. Export portable proof bundle
remembrancer export-proof path/to/artifact

# 8. Verify audit log integrity
remembrancer verify-audit

# 9. Update receipts index
./ops/bin/receipts-site

# 10. Commit and push to main
git add -A
git commit -m "governance: record proposal-<N> with dual timestamps"
git push origin main
```

### Chain Reference Format

| Chain | Format | Example |
|-------|--------|---------|
| Ethereum Mainnet | `eip155:1/tx:0x<txhash>` | `eip155:1/tx:0xabc123...` |
| Polygon | `eip155:137/tx:0x<txhash>` | `eip155:137/tx:0xdef456...` |
| Arbitrum | `eip155:42161/tx:0x<txhash>` | `eip155:42161/tx:0x789abc...` |
| Safe Execution | `eip155:1/safe:0x<safe>/tx:0x<txhash>` | `eip155:1/safe:0x123.../tx:0xabc...` |
| Snapshot Proposal | `snapshot:<space>/proposal/<id>` | `snapshot:mydao.eth/proposal/0x123...` |

### Quick Commands

```bash
# List all recorded deployments
remembrancer list deployments

# Query specific decision
remembrancer query "proposal-<N>"

# View receipt
remembrancer receipt deploy/dao-governance-proposal-<N>

# Timeline view
remembrancer timeline --since 2025-01-01
```

---

## Emergency Procedures

### TSA Outage

**Symptoms:**
- `remembrancer timestamp` fails
- `curl https://freetsa.org/tsr` returns error

**Response:**

```bash
# 1. Switch to alternate TSA
export REMEMBRANCER_TSA_URL=$REMEMBRANCER_TSA_URL_2

# 2. Timestamp with alternate
remembrancer timestamp path/to/artifact

# 3. Create OUTAGE_NOTE receipt
cat > ops/receipts/incidents/tsa-outage-$(date +%Y%m%d).md <<EOF
# TSA Outage Incident

**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Affected TSA:** $REMEMBRANCER_TSA_URL_1
**Response:** Switched to alternate TSA ($REMEMBRANCER_TSA_URL_2)
**Artifacts affected:** [list]
**Status:** Monitoring primary TSA for recovery

## Recovery Plan
1. Monitor primary TSA status
2. When recovered, create dual timestamp for affected artifacts
3. Backfill receipts with both timestamps
4. Verify dual-rail on all affected artifacts
EOF

# 4. When primary recovers, backfill
remembrancer timestamp path/to/artifact  # Uses primary TSA
```

### Receipt Tamper Detection

**Symptoms:**
- `remembrancer verify-audit` fails
- Merkle root mismatch

**Response:**

```bash
# 1. Identify tampered receipts
remembrancer verify-audit 2>&1 | tee ops/receipts/incidents/tamper-$(date +%Y%m%d).log

# 2. Raise Black Flag (freeze all operations)
echo "BLACK_FLAG: Receipt tamper detected at $(date)" | tee BLACK_FLAG.txt

# 3. Compare with peer node (if federated)
./ops/bin/fed-merge --compare <peer_url>

# 4. Deterministic reconciliation
./ops/bin/fed-merge \
  --left ops/data/local-log.json \
  --right ops/data/peer-log.json \
  --out ops/receipts/merge/reconciliation-$(date +%Y%m%d).receipt

# 5. Operator signs MERGE_RECEIPT
gpg --armor --detach-sign \
  -u $REMEMBRANCER_KEY_ID \
  ops/receipts/merge/reconciliation-$(date +%Y%m%d).receipt

# 6. Recompute Merkle and verify
remembrancer verify-audit

# 7. Clear Black Flag if resolved
rm BLACK_FLAG.txt
```

### Key Compromise

**Response:**

```bash
# 1. Generate revocation certificate (if not pre-generated)
gpg --output revoke-$REMEMBRANCER_KEY_ID.asc \
  --gen-revoke $REMEMBRANCER_KEY_ID

# 2. Create REVOCATION_RECEIPT
cat > ops/receipts/incidents/key-revocation-$(date +%Y%m%d).md <<EOF
# Key Revocation

**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Old Key:** $REMEMBRANCER_KEY_ID
**New Key:** <new_key_id>
**Reason:** Key compromise detected

## Actions Taken
1. Revoked old key
2. Rotated to new key
3. Re-signed last N receipts
4. Dual-timestamped revocation receipt
EOF

# 3. Rotate to new key
export REMEMBRANCER_KEY_ID="<new_key_id>"

# 4. Re-sign recent receipts (last 30 days)
find ops/receipts -name "*.receipt" -mtime -30 -exec \
  remembrancer sign {} --key $REMEMBRANCER_KEY_ID \;

# 5. Timestamp revocation receipt
remembrancer timestamp ops/receipts/incidents/key-revocation-$(date +%Y%m%d).md

# 6. Publish revocation and new key
gpg --armor --export $REMEMBRANCER_KEY_ID > ops/certs/dao-key-new.asc
```

---

## Verification Commands

### Verify Specific Artifact

```bash
# Full chain verification
remembrancer verify-full path/to/artifact

# Individual components
gpg --verify path/to/artifact.asc path/to/artifact
openssl ts -reply -in path/to/artifact.tsr -text
./ops/bin/rfc3161-verify path/to/artifact
```

### Verify Merkle Audit Log

```bash
# Verify audit log integrity
remembrancer verify-audit

# Expected output:
# ✅ Audit log integrity verified (root=d5c64aee...)
```

### Verify Federation Merge

```bash
# Self-test deterministic merge
./ops/bin/fed-merge --self-test

# Expected output:
# MERGE_ROOT b048198b331bcd27a2cc1f4265c7bde63869ed91f02568e76bd757eedc9da03b
```

---

## Troubleshooting

### "GPG agent not available"

```bash
# Start gpg-agent
gpgconf --launch gpg-agent

# Or use batch mode
export GPG_TTY=$(tty)
```

### "TSA certificate verification failed"

```bash
# Re-fetch TSA certificates
rm -rf ops/certs/cache/*
./ops/bin/tsa-bootstrap

# Verify SPKI pins are correct
openssl x509 -in ops/certs/cache/public.ca.pem -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | base64
```

### "Merkle root mismatch"

```bash
# Check for uncommitted changes
git status

# Recompute Merkle root
remembrancer verify-audit

# If persistent, investigate:
sqlite3 ops/data/remembrancer.db "SELECT * FROM memories ORDER BY timestamp DESC LIMIT 10;"
```

### "Docker build not reproducible"

```bash
# Ensure SOURCE_DATE_EPOCH is set
make repro

# Check image digest
docker image inspect vm/repro:$(git rev-parse --short HEAD) --format '{{.Id}}'

# Compare to canonical
diff ops/artifacts/repro.id ops/receipts/build/repro.id
```

---

## Routine Maintenance

### Weekly

- [ ] Run `make covenant` and verify all pass
- [ ] Review `ops/receipts/` for new receipts
- [ ] Update receipts index: `./ops/bin/receipts-site`

### Monthly

- [ ] Verify TSA certificates still valid
- [ ] Test dual-rail verification on random sample
- [ ] Review Merkle audit log for anomalies
- [ ] Backup `ops/data/remembrancer.db`

### Quarterly

- [ ] Rotate TSA SPKI pins (if changed)
- [ ] Test key revocation procedure (dry-run)
- [ ] Review and update operator runbook
- [ ] Test federation merge with peer (if applicable)

---

## Quick Reference Card

```bash
# Health & Status
./ops/bin/health-check          # System health (16 checks)
make covenant                    # Four Covenants validation
remembrancer verify-audit        # Merkle integrity

# Recording
remembrancer record deploy ...   # Record decision
remembrancer sign <artifact>     # GPG sign
remembrancer timestamp <artifact> # RFC 3161 timestamp
remembrancer verify-full <artifact> # Verify chain

# Transparency
./ops/bin/receipts-site         # Generate index
remembrancer list deployments   # List all
remembrancer query "<term>"     # Search

# Emergency
BLACK_FLAG.txt                  # Freeze marker
./ops/bin/fed-merge --compare   # Peer reconciliation
gpg --gen-revoke $KEY           # Key revocation
```

---

**Operator Hotline (Emergency):**
- Merkle mismatch → See "Receipt Tamper Detection"
- TSA outage → See "TSA Outage"
- Key compromise → See "Key Compromise"

🜄 **Astra inclinant, sed non obligant. The DAO remains sovereign.**

