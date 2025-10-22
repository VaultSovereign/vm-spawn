# Aurora GA Verification Guide (v1.0.0)

**Checksum:** `acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8`  
**GPG Key:** 6E4082C6A410F340  
**Tag:** v1.0.0-aurora  
**Release Date:** 2025-10-22

---

## 1️⃣ Verify from GitHub Release

```bash
# Download release artifacts
curl -LO https://github.com/VaultSovereign/vm-spawn/releases/download/v1.0.0-aurora/aurora-20251022.tar.gz
curl -LO https://github.com/VaultSovereign/vm-spawn/releases/download/v1.0.0-aurora/aurora-20251022.tar.gz.asc

# Import GPG key
gpg --keyserver hkps://keys.openpgp.org --recv-keys 6E4082C6A410F340

# Verify signature
gpg --verify aurora-20251022.tar.gz.asc aurora-20251022.tar.gz

# Verify checksum
shasum -a 256 aurora-20251022.tar.gz
# Expected: acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8
```

**Expected output:**
```
gpg: Good signature from "Sovereign <sovereign@vaultmesh.io>"
acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8  aurora-20251022.tar.gz
```

---

## 2️⃣ Verify from Source

```bash
# Clone repository
git clone https://github.com/VaultSovereign/vm-spawn.git
cd vm-spawn

# Verify signed tag
git tag -v v1.0.0-aurora
# Expected: gpg: Good signature from "Sovereign <sovereign@vaultmesh.io>"

# Build release bundle
make dist KEY=6E4082C6A410F340

# Verify checksum matches
shasum -a 256 dist/aurora-*.tar.gz
# Should match: acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8
```

---

## 3️⃣ Verify Provenance Receipts

Each compute job emits cryptographic proof:

```bash
# Verify receipt structure
cat artifacts/receipt-example.json | jq .

# Verify Merkle root
./ops/bin/remembrancer verify-audit

# Verify RFC3161 timestamp
openssl ts -verify -data artifacts/job-123.tar.gz \
  -in artifacts/job-123.tar.gz.tsr \
  -CAfile ops/certs/freetsa-ca.pem

# Verify IPFS pinning
ipfs cat <CID_from_receipt>
```

**Receipt schema:**
```json
{
  "job_id": "aurora-job-123",
  "treaty_id": "AURORA-AKASH-001",
  "merkle_root": "0x...",
  "timestamp_token": "base64...",
  "ipfs_cid": "Qm...",
  "signature": "ed25519..."
}
```

---

## 4️⃣ Verify Ledger Provenance (Optional)

Check that job receipts reference the same Merkle root recorded in the intelligence-ledger database:

```bash
# Query ledger
sqlite3 ops/data/remembrancer.db "SELECT merkle_root FROM audit_log ORDER BY timestamp DESC LIMIT 1;"

# Compare with receipt
cat artifacts/receipt-example.json | jq -r .merkle_root

# Both should match
```

---

## 5️⃣ Verify WASM Policy

```bash
# Extract policy from bundle
tar -xzf aurora-20251022.tar.gz policy/wasm/vault-law-akash-policy.wasm

# Verify WASM module
wasm-objdump -h policy/wasm/vault-law-akash-policy.wasm

# Test policy execution
python3 scripts/policy-host-adapter.py \
  --wasm policy/wasm/vault-law-akash-policy.wasm \
  --input test-order.json
```

---

## 6️⃣ Verify Schemas

```bash
# Validate order against schema
jq . templates/aurora-treaty-akash.json | \
  jsonschema -i /dev/stdin schemas/aurora-treaty-order.schema.json

# Validate ACK against schema
jq . test-ack.json | \
  jsonschema -i /dev/stdin schemas/axelar-ack.schema.json
```

---

## Quick Verification (One Command)

```bash
# Run complete verification suite
./verify.sh

# Expected output:
# ✅ GPG signature valid
# ✅ SHA256 checksum matches
# ✅ Merkle audit passes
# ✅ RFC3161 timestamp valid
# ✅ WASM policy loads
# ✅ Schemas validate
```

---

## Aurora GA is Fully Reproducible

- **Source** → deterministic WASM build
- **Signed tag** → verified bundle
- **Checksum** → matched artifact
- **Receipts** → timestamped + pinned
- **Ledger** → Merkle-audited

**The covenant is cryptographically enforced. Truth is provable.**

---

## Troubleshooting

### GPG key not found
```bash
gpg --keyserver hkps://keys.openpgp.org --recv-keys 6E4082C6A410F340
# Alternative keyserver:
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 6E4082C6A410F340
```

### Checksum mismatch
- Ensure you downloaded the correct release (v1.0.0-aurora)
- Verify no corruption during download: `curl -L --retry 3 ...`
- Compare with CHECKSUMS.txt in release

### Timestamp verification fails
- Ensure FreeTSA CA cert is present: `ops/certs/freetsa-ca.pem`
- Download if missing: `curl -o ops/certs/freetsa-ca.pem https://freetsa.org/files/cacert.pem`

---

**For support:** See `docs/AURORA_RUNBOOK.md` or file an issue at https://github.com/VaultSovereign/vm-spawn/issues
