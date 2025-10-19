# Covenant Rituals — Operator Cheatsheet

## Daily: Publish Merkle Root (if DB updated)
```bash
./ops/bin/publish-merkle-root.sh
git add docs/REMEMBRANCER.md
git commit -m "chore: publish Merkle root $(date +%Y-%m-%d)"
git push
```

## Release: Attest Artifact
```bash
# 1. Build artifact
tar -czf dist/vaultmesh-v3.1.0.tar.gz src/

# 2. Attest
./ops/bin/attest-artifact.sh dist/vaultmesh-v3.1.0.tar.gz <your-gpg-key>

# 3. Create receipt
./ops/bin/remembrancer record-receipt-v3 vaultmesh v3.1.0 \
  dist/vaultmesh-v3.1.0.tar.gz <your-gpg-key> \
  > ops/receipts/deploy/vaultmesh-v3.1.0.receipt

# 4. Verify
./ops/bin/remembrancer verify-full dist/vaultmesh-v3.1.0.tar.gz

# 5. Commit proofs
git add dist/vaultmesh-v3.1.0.* ops/receipts/deploy/vaultmesh-v3.1.0.receipt
git commit -m "release: vaultmesh v3.1.0 with full proof chain"
git tag -a v3.1.0 -m "VaultMesh v3.1.0"
git push origin main --tags
```

## Weekly: Audit Check
```bash
./ops/bin/remembrancer verify-audit
# Should output: ✅ Audit log integrity verified
```

## Monthly: Backup
```bash
# Backup DB
cp ops/data/remembrancer.db ~/backups/remembrancer-$(date +%Y%m%d).db

# Backup receipts
tar -czf ~/backups/receipts-$(date +%Y%m%d).tar.gz ops/receipts/
```

