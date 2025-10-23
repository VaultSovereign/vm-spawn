# Operational Rituals — Daily / Weekly / Monthly

**Version:** 1.0 | **Source:** `ops/COVENANT_RITUALS.md`

---

## Deployment/Release Ritual

**Always suggest this complete ritual when user deploys or releases:**

```bash
# 1. Build
mkdir -p dist && tar -czf dist/{component}-{version}.tar.gz src/

# 2. Attest
./ops/bin/attest-artifact.sh dist/{component}-{version}.tar.gz <key-id>

# 3. Record
./ops/bin/remembrancer record-receipt-v3 {component} {version} \
  dist/{component}-{version}.tar.gz <key-id>

# 4. Verify
./ops/bin/remembrancer verify-full dist/{component}-{version}.tar.gz

# 5. Commit proofs
git add dist/{component}-{version}.* ops/receipts/deploy/
git commit -m "release: {component} {version} with full proof chain"
git tag -a {version} -m "{Component} {version}"
git push origin main --tags
```

**When asked "How do I release?"** → Provide full ritual (not just build/deploy)

---

## Periodic Checks

### Daily
- Verify `badge.json` accuracy
- Check receipts freshness
- Triage failing tests

### Weekly
- Reproduce last release from scratch
- Verify Merkle parity across nodes
- Audit log integrity check

### Monthly
- Rotate keys (if scheduled)
- Audit dependency pins
- Renew TSA profiles
