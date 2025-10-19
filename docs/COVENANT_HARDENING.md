# Covenant Hardening Guide

VaultMesh v3.0 introduced cryptographic verification. This guide documents the hardening measures to ensure all future artifacts maintain the covenant.

## Invariants

Every production artifact MUST:
1. Have SHA256 hash computed
2. Have GPG detached signature (`.asc` file)
3. Have RFC3161 timestamp (`.tsr` file)
4. Pass `remembrancer verify-full` check
5. Be recorded in Remembrancer with receipt

## CI Enforcement

`.github/workflows/covenant-guard.yml` runs on:
- Every push to main
- Every release tag (`v*.*.*`)
- Every pull request

Guards:
- Lints `ops/bin/remembrancer` with shellcheck
- Verifies Python syntax (`ops/lib/merkle.py`)
- Runs `verify-full` on all `dist/` artifacts
- Checks Merkle root integrity

## Local Rituals

### Publish Merkle Root
```bash
./ops/bin/publish-merkle-root.sh
git add docs/REMEMBRANCER.md
git commit -m "chore: publish Merkle root"
```

### Attest New Artifact
```bash
./ops/bin/attest-artifact.sh dist/my-release.tar.gz my-gpg-key
```

### Verify Existing Artifact
```bash
./ops/bin/remembrancer verify-full dist/artifact.tar.gz
```

## TSA Certificate Management

TSA CAs are NOT committed to git. Each operator:
1. Downloads TSA CA (e.g., FreeTSA)
2. Verifies fingerprint out-of-band
3. Places at `ops/certs/freetsa-ca.pem`
4. Configures via `FREETSA_CA` env var

## Recovery Procedures

### Suspected Tampering
```bash
# Export DB snapshot
sqlite3 -json ops/data/remembrancer.db 'SELECT * FROM memories ORDER BY timestamp,id;' > /tmp/memories.json

# Recompute root
python3 ops/lib/merkle.py --compute --from-json /tmp/memories.json

# Compare with published
grep -m1 "^Merkle Root:" docs/REMEMBRANCER.md | awk '{print $3}'
```

If mismatch: binary search timestamp ranges to find divergent rows, restore from last good commit.

## Pre-commit Hook

Install locally:
```bash
./ops/bin/install-hooks.sh
```

Blocks accidental commit of TSA CA PEMs.

