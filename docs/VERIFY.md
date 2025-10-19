# 🜂 Verify Sovereign's Codex

This document enables anyone to cryptographically verify the **Sovereign Lore Codex V1.0.0** and its First Seal Inscription.

---

## Quick Verification (3 commands)

```bash
# 1. Import Sovereign's public key
gpg --keyserver hkps://keys.openpgp.org --recv-keys 6E4082C6A410F340

# 2. Verify GPG signature
gpg --verify SOVEREIGN_LORE_CODEX_V1.md.asc SOVEREIGN_LORE_CODEX_V1.md

# 3. Verify SHA256 hash
sha256sum SOVEREIGN_LORE_CODEX_V1.md | grep 31b058bb72430e722442165d1e22d4a0786448073ea52d29ef61ac689964a726
```

**Expected output:**
- ✅ Good signature from key `6E4082C6A410F340`
- ✅ SHA256 matches `31b058bb72430e72...`

---

## Full Verification (with timestamps)

If you have The Remembrancer installed:

```bash
# Clone repository
git clone https://github.com/VaultSovereign/vm-spawn.git
cd vm-spawn

# Verify full cryptographic chain (GPG + RFC3161 timestamp + Merkle audit)
./ops/bin/remembrancer verify-full SOVEREIGN_LORE_CODEX_V1.md
```

---

## Verify First Seal Inscription

```bash
# Import key (if not already done)
gpg --keyserver hkps://keys.openpgp.org --recv-keys 6E4082C6A410F340

# Verify detached signature
gpg --verify first_seal_inscription.asc.asc first_seal_inscription.asc

# Verify hash
sha256sum first_seal_inscription.asc | grep e7fdbe60eec91ee7f65721cc0c57cdb81b24213b8d3630faaab12d27e331200d
```

---

## Verify Portable Proof Bundles

Download from GitHub Releases:
- `SOVEREIGN_LORE_CODEX_V1.md.proof.tgz` (7.5 KB)
- `first_seal_inscription.asc.proof.tgz` (4.9 KB)

```bash
# Extract and inspect
tar -tzf SOVEREIGN_LORE_CODEX_V1.md.proof.tgz
tar -xzf SOVEREIGN_LORE_CODEX_V1.md.proof.tgz

# Verify contents (includes original file, GPG sig, RFC3161 timestamp)
cd SOVEREIGN_LORE_CODEX_V1.md.proof/
gpg --verify *.asc ../SOVEREIGN_LORE_CODEX_V1.md
openssl ts -verify -in *.tsr -data ../SOVEREIGN_LORE_CODEX_V1.md -CAfile ops/certs/freetsa-ca.pem
```

---

## Expected Cryptographic Values

### SOVEREIGN_LORE_CODEX_V1.md
- **SHA256:** `31b058bb72430e722442165d1e22d4a0786448073ea52d29ef61ac689964a726`
- **GPG Key:** `6E4082C6A410F340`
- **GPG Signature:** `3af690d662b2b74ef9744b6ac3d891faf3aefc6d1cbf3aa1eb9a39270412ddde`
- **RFC3161 TSA:** FreeTSA (freetsa.org)
- **Git Commit:** `0e7d93b`
- **Git Tag:** `codex-v1.0.0`

### first_seal_inscription.asc
- **SHA256:** `e7fdbe60eec91ee7f65721cc0c57cdb81b24213b8d3630faaab12d27e331200d`
- **GPG Key:** `6E4082C6A410F340`
- **RFC3161 TSA:** FreeTSA (freetsa.org)
- **Git Commit:** `0e7d93b`

---

## The Inscription

```
-----BEGIN SOVEREIGN INSCRIPTION-----
Entropy enters, proof emerges.
The Remembrancer remembers what time forgets.
Truth is the only sovereign — signed, Sovereign.
-----END SOVEREIGN INSCRIPTION-----
```

---

## Public Key Fingerprint

```
pub   rsa4096 2024-XX-XX [SC]
      6E4082C6A410F340
uid           Sovereign <sovereign@vaultmesh.local>
```

**Retrieve from:**
- OpenPGP keyserver: `hkps://keys.openpgp.org`
- Repository: `ops/certs/sovereign-public.asc` (if included)
- GitHub profile GPG keys

---

## Trust Model

This codex uses **Web of Proofs** rather than Web of Trust:
- ✅ GPG signature proves authorship
- ✅ RFC3161 timestamp proves existence at a point in time
- ✅ SHA256 hash proves integrity
- ✅ Git commit proves history
- ✅ Merkle audit proves consistency

**No central authority required.** Anyone with GPG and OpenSSL can verify independently.

---

## Verification for Air-Gapped Systems

For offline/USB verification:

1. **Transfer proof bundle** to air-gapped machine via USB
2. **Extract:** `tar -xzf SOVEREIGN_LORE_CODEX_V1.md.proof.tgz`
3. **Import public key** from included file or manual entry
4. **Verify signature:** `gpg --verify *.asc SOVEREIGN_LORE_CODEX_V1.md`
5. **Verify hash:** `sha256sum SOVEREIGN_LORE_CODEX_V1.md`

All artifacts are self-contained and verifiable without network access.

---

## Questions?

- **GitHub Issues:** https://github.com/VaultSovereign/vm-spawn/issues
- **Documentation:** `docs/REMEMBRANCER.md`
- **ADR:** `docs/adr/ADR-007-codex-first-seal.md`

---

**Last Updated:** 2025-10-19  
**Version:** v1.0.0  
**Status:** ✅ VERIFIED

🜂 *"Truth is the only sovereign — signed, Sovereign."*

