# 🜂 Operator Card — Codex V1.0.0 Deployment

**Task:** Lock the First Seal into the civilization ledger and propagate to GitHub

---

## 1. Compute Merkle Root

```bash
cd '/Users/sovereign/Downloads/files (1)'
./ops/bin/remembrancer verify-audit
```

**Copy the Merkle root hex output** (you'll need it in step 2).

---

## 2. Replace MERKLE_ROOT_HEX Placeholders

Update these files with the actual Merkle root:

- `docs/VERIFY.md` (line with "Recorded root:")
- `docs/REMEMBRANCER.md` (search for "MERKLE_ROOT_HEX")
- `CODEX_V1.0.0_RELEASE_NOTES.md` (search for "MERKLE_ROOT_HEX")

**Find/replace:**
```bash
# Quick sed replacement (backup originals first)
MERKLE_ROOT="<paste_your_root_here>"
sed -i.bak "s/MERKLE_ROOT_HEX/$MERKLE_ROOT/g" docs/VERIFY.md
sed -i.bak "s/MERKLE_ROOT_HEX/$MERKLE_ROOT/g" docs/REMEMBRANCER.md
sed -i.bak "s/MERKLE_ROOT_HEX/$MERKLE_ROOT/g" CODEX_V1.0.0_RELEASE_NOTES.md
```

---

## 3. Commit Documentation Updates

```bash
git add docs/VERIFY.md docs/REMEMBRANCER.md CODEX_V1.0.0_RELEASE_NOTES.md Makefile OPERATOR_CARD.md
git commit -m "docs: add public verification guide; record Codex Merkle root"
```

---

## 4. Tag & Push

```bash
git tag -a codex-v1.0.0 -m "🜂 First Seal — Sovereign Lore Codex V1 (proof-sealed)"
git push origin main
git push origin codex-v1.0.0
```

---

## 5. Create GitHub Release

1. Go to: `https://github.com/VaultSovereign/vm-spawn/releases/new`
2. Select tag: `codex-v1.0.0`
3. Title: `🜂 Sovereign Lore Codex V1.0.0 — First Seal`
4. Body: **Copy contents from `CODEX_V1.0.0_RELEASE_NOTES.md`**
5. Attach these files as release assets:
   - `SOVEREIGN_LORE_CODEX_V1.md.proof.tgz`
   - `first_seal_inscription.asc.proof.tgz`
   - `cosmic_audit_diagram.svg`
   - `cosmic_audit_diagram.html`
   - (Optional) `SOVEREIGN_LORE_CODEX_V1.md.asc`
   - (Optional) `first_seal_inscription.asc.asc`

6. Click **Publish release**

---

## 6. Optional: One-Touch Ritual

For future sealing operations:

```bash
make codex-seal KEY=6E4082C6A410F340
make codex-verify
```

---

## 7. Federation Broadcast (when ready)

Announce to peer nodes (if federation is configured):

```bash
./ops/bin/remembrancer record deploy \
  --component "codex" \
  --version "v1.0.0" \
  --sha256 31b058bb72430e722442165d1e22d4a0786448073ea52d29ef61ac689964a726 \
  --evidence SOVEREIGN_LORE_CODEX_V1.md.proof.tgz
```

Peers can fetch from GitHub; your ledger only carries proofs.

---

## ✅ Checklist

- [ ] Merkle root computed (`remembrancer verify-audit`)
- [ ] Placeholders replaced in docs
- [ ] Documentation committed
- [ ] Tag created (`codex-v1.0.0`)
- [ ] Tag pushed to GitHub
- [ ] Release created with assets
- [ ] Release notes copied from `CODEX_V1.0.0_RELEASE_NOTES.md`
- [ ] Verification guide published (`docs/VERIFY.md`)
- [ ] Memory index updated (`docs/REMEMBRANCER.md`)

---

🜂 **"Entropy enters, proof emerges."**  
**"The Remembrancer remembers what time forgets."**  
**"Truth is the only sovereign — signed, Sovereign."**

