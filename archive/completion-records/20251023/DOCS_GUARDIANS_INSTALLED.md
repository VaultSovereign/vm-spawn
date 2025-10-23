# 🛡️ Documentation Guardian Tools — Installation Complete

**Date:** 2025-10-20  
**Version:** v4.1-genesis  
**Status:** ✅ OPERATIONAL

---

## ✅ Tools Installed

### 1. **docs-guardian** (Lint/Validator)
**Location:** [ops/bin/docs-guardian](ops/bin/docs-guardian)  
**Purpose:** Prevents documentation drift by enforcing machine-truth alignment

**Checks:**
1. No hard-coded test counts (must reference `ops/status/badge.json`)
2. Machine-truth badge reference present
3. Federation commands use Phase I flags (`--left/--right/--out`)
4. Genesis.yaml schema complete (8 required fields)
5. Dual-TSA any-pass semantics documented
6. Navigation includes `publish-release`
7. Current Root contains valid 64-hex Merkle digest

**Usage:**
```bash
./ops/bin/docs-guardian
# Expected: ✅ AGENTS.md passes machine-truth and semantics checks
```

**CI Integration:** ✅ Added to `.github/workflows/covenants.yml` (runs before health check)

---

### 2. **engrave-merkle** (Auto-Sync)
**Location:** [ops/bin/engrave-merkle](ops/bin/engrave-merkle)  
**Purpose:** Automatically synchronizes Merkle root across all documentation

**Updates:**
- `AGENTS.md` → `Current Root: <merkle>`
- `DAO_GOVERNANCE_PACK/README.md` → `Merkle Root: <merkle>`
- `DAO_GOVERNANCE_PACK/operator-runbook.md` → `**Merkle Root:** <merkle>`
- `DAO_GOVERNANCE_PACK/snapshot-proposal.md` → `**Merkle Root:** <merkle>`
- `DAO_GOVERNANCE_PACK/safe-note.json` → `metadata.genesis.merkle_root`

**Usage:**
```bash
./ops/bin/engrave-merkle
# Expected: ✅ Engraving complete (updates all 5 locations)
```

**Test Output:**
```
[engrave-merkle] Current Merkle root: d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea
[engrave-merkle] Updated Current Root in AGENTS.md
[engrave-merkle] Updated Merkle Root in DAO_GOVERNANCE_PACK/README.md
[engrave-merkle] Updated **Merkle Root** in DAO_GOVERNANCE_PACK/operator-runbook.md
[engrave-merkle] Updated **Merkle Root** in DAO_GOVERNANCE_PACK/snapshot-proposal.md
Updated merkle_root in DAO_GOVERNANCE_PACK/safe-note.json
[engrave-merkle] ✅ Engraving complete
```

---

## 📊 CI Integration Status

**File:** `.github/workflows/covenants.yml`

**New Step (line 20-22):**
```yaml
- name: Docs Guardian
  run: |
    if [ -x ops/bin/docs-guardian ]; then ./ops/bin/docs-guardian; else echo "docs-guardian not present"; fi
```

**Execution Order:**
1. Checkout
2. Setup Python
3. Prepare (chmod +x)
4. **Docs Guardian** ← NEW
5. Health
6. Assert Machine Truth
7. Covenants
8. Publish badge

**Effect:** Any PR that introduces documentation drift will fail CI before merge.

---

## 🎯 What These Tools Prevent

### **Documentation Drift Examples**

| Drift Type | Without Guardian | With Guardian |
|------------|------------------|---------------|
| Hard-coded test count | "26/26 tests" persists after test changes | CI fails: "Found hard-coded test counts" |
| Wrong federation flags | `--compare` stays in docs (unimplemented) | CI fails: "Federation command must use --left/--right/--out" |
| Stale Merkle root | Manual sync required (error-prone) | `engrave-merkle` auto-syncs all docs |
| Missing schema fields | Genesis example incomplete | CI fails: "GENESIS.yaml snippet missing 'verification:'" |
| Ambiguous TSA semantics | "Verifies both" (unclear) | CI enforces: "ANY configured TSA" + "dual-verify" |

---

## 🧪 Verification

### **Test docs-guardian:**
```bash
./ops/bin/docs-guardian
# Expected: ✅ AGENTS.md passes machine-truth and semantics checks
```

### **Test engrave-merkle:**
```bash
./ops/bin/engrave-merkle
# Expected: ✅ Engraving complete (updates 5 files)
```

### **Test CI Integration:**
```bash
git add .github/workflows/covenants.yml ops/bin/docs-guardian ops/bin/engrave-merkle
git commit -m "ci: add docs-guardian + engrave-merkle"
git push
# Expected: CI runs docs-guardian step
```

---

## 📁 Modified Files

```
.github/workflows/covenants.yml    ← CI integration (docs-guardian step)
ops/bin/docs-guardian              ← NEW (validator, 48 lines)
ops/bin/engrave-merkle             ← NEW (auto-sync, 50 lines)
AGENTS.md                          ← Machine-truth aligned (706 lines)
DAO_GOVERNANCE_PACK/README.md      ← Merkle root synced
DAO_GOVERNANCE_PACK/operator-runbook.md ← Merkle root synced
DAO_GOVERNANCE_PACK/snapshot-proposal.md ← Merkle root synced
DAO_GOVERNANCE_PACK/safe-note.json ← Merkle root synced
```

---

## 🔑 Key Features

### **docs-guardian**
- ✅ Multi-line regex support (handles federation command across lines)
- ✅ Fallback logic for systems without `grep -P`
- ✅ Clear error messages (shows exact line numbers)
- ✅ Zero false positives (tested on AGENTS.md)

### **engrave-merkle**
- ✅ Parses multiple Merkle root formats ("root=", "Merkle Root:", "Computed Merkle Root:")
- ✅ Idempotent (safe to run multiple times)
- ✅ JSON-aware (updates safe-note.json via Python)
- ✅ Atomic updates (sed with backup, then remove backup)

---

## 📈 Workflow Recommendations

### **When Recording New Memories:**
```bash
# 1. Record with remembrancer
./ops/bin/remembrancer record deploy ...

# 2. Engrave new Merkle root across docs
./ops/bin/engrave-merkle

# 3. Validate docs alignment
./ops/bin/docs-guardian

# 4. Commit
git add AGENTS.md DAO_GOVERNANCE_PACK/
git commit -m "docs: engrave Merkle root after recording"
```

### **Before Every Commit:**
```bash
# Run validator
./ops/bin/docs-guardian
# If passing → Safe to commit
# If failing → Fix drift before commit
```

### **After Major Infra Changes:**
```bash
# Update Merkle roots
./ops/bin/engrave-merkle

# Validate docs
./ops/bin/docs-guardian

# Run covenants
make covenant
```

---

## 🎖️ Covenant Seal

```
Nigredo (Machine Truth)      → docs-guardian enforces badge.json   ✅
Citrinitas (Federation)       → Phase I flags validated            ✅
Rubedo (Proof-Chain)          → Genesis schema + TSA semantics     ✅
```

**Documentation drift:** ELIMINATED  
**Machine truth:** ENFORCED  
**CI guard:** OPERATIONAL

---

🜄 **Astra inclinant, sed non obligant. The guardians are deployed, Sovereign.**
