# Root Directory Cleanup Analysis

**Date:** 2025-10-24
**Goal:** Align with "Digital Civilization" vision - clean root, organized docs
**Current:** 23 markdown files at root (still too many)

---

## ✅ Cleanup Completed (This Session)

### Removed IDE/Tool Directories
- ❌ `.amazonq/` (8 files) - Removed from git
- ❌ `.claude/` (1 file) - Removed from git
- ❌ `.continue/` (1 file) - Removed from git
- ✅ Added to `.gitignore`

### Removed Generated Files
- ❌ `canary_slo_report.json` - Generated report
- ❌ `codex-fed.json` - Generated data
- ✅ Added pattern to `.gitignore`

### Archived Historical Files
- 📦 `first_seal_inscription.asc*` (5 files) → `archive/genesis-proofs/`
- 📦 `cosmic_audit_diagram.*` (2 files) → `archive/diagrams/`
- 📦 `DEPLOYMENT_COMPLETE_100_PERCENT.md` → `archive/deployments/2025-10-23/`
- 📦 `EXECUTION_STATUS.md` → `archive/deployments/2025-10-23/`

### Security Fix
- 🔒 Removed hardcoded Cloudflare API token
- 🔒 Updated script to use environment variables
- 🔒 Created `SECURITY_INCIDENT_2025-10-24.md`

**Files Cleaned:** 24 files removed/moved

---

## 📊 Remaining Root Files (23 Markdown Files)

### ✅ KEEP at Root (Core Documentation)
1. `README.md` - Civilization Engine vision ✅
2. `CHANGELOG.md` - Version history ✅
3. `CONTRIBUTING.md` - Contribution guide ✅
4. `SECURITY.md` - Security policy ✅

**Goal:** These 4 + maybe GETTING_STARTED.md = **5 files max at root**

---

### ⚠️  SHOULD MOVE (18 Files to Relocate)

#### Vision/Philosophy (→ docs/vision/)
5. `SOVEREIGN_LORE_CODEX_V1.md` - Lore and philosophy
6. `PROPOSAL_9_9_EXCELLENCE.md` - Excellence philosophy
7. `ALCHEMICAL_EXECUTION_KIT.md` - Execution philosophy

#### Architecture/Agents (→ docs/architecture/)
8. `AGENTS.md` - Agent architecture (27KB!)
9. `AI_AGENT_QUICKSTART.md` - AI agent guide

#### Operations/Status (→ docs/operations/)
10. `STATUS.md` - Current project status
11. `GCP_DEPLOYMENT_STATUS.md` - GCP deployment status
12. `GCP_COST_COMPARISON.md` - Cost analysis
13. `KPI_DEPLOYMENT_FINAL_STATUS.md` - Old deployment status (archive?)

#### Guides (→ docs/guides/)
14. `GETTING_STARTED_AURORA_ROUTER.md` - Aurora guide
15. `VAULTMESH_ANALYTICS_STATUS.md` - Analytics guide
16. `START_HERE.md` - Getting started (merge into main README?)

#### Evolution/Roadmap (→ docs/evolution/)
17. `PRODUCTION_ROUTER_ROADMAP.md` - Router roadmap
18. `EXPERIMENTAL_SERVICES.md` - Experimental features

#### Meta/Administrative (→ archive/planning/)
19. `README_IMPORTANT.md` - Old important notes
20. `PR_SUMMARY_2025-10-24.md` - PR summary (archive after merge)
21. `RESTRUCTURE_PROPOSAL.md` - This proposal (archive after completion)
22. `SECURITY_INCIDENT_2025-10-24.md` - Security incident (move to docs/security/)

---

## 🚫 Files/Directories That SHOULD NOT Be in Main

### Untracked Directories (Add to .gitignore or delete)
- `sim/ai-mesh/` - Simulation outputs (should be in sim/*/out/ pattern)
- `vaultmesh-us-mcp/` - Separate project? Or move to services/?
- `vaultmesh-phase-vi (1).zip` - Temporary archive file

### Generated Files (Already in .gitignore)
- `*.log` files
- `node_modules/`
- `out/` directories

---

## 📋 Proposed Action Plan

### Phase 1: Security & IDE Cleanup (NOW - This Commit)
```bash
✅ Remove IDE dirs (.amazonq, .claude, .continue)
✅ Remove generated files (canary_slo_report.json, codex-fed.json)
✅ Archive historical proofs (first_seal_inscription.asc*)
✅ Archive old deployment docs
✅ Fix Cloudflare token security issue
✅ Update .gitignore
```

### Phase 2: Move Untracked Files (Next Commit)
```bash
# Move planning docs to archive
mv PR_SUMMARY_2025-10-24.md archive/planning/
mv RESTRUCTURE_PROPOSAL.md archive/planning/

# Cleanup temp files
rm -rf "vaultmesh-phase-vi (1).zip"

# Decide on vaultmesh-us-mcp:
# Option A: Move to services/ if it's a service
# Option B: Add to .gitignore if separate project
# Option C: Archive if obsolete
```

### Phase 3: Documentation Restructure (PR #20)
```bash
# Create docs/ structure
mkdir -p docs/{vision,architecture,guides,operations,evolution}

# Move markdown files (see RESTRUCTURE_PROPOSAL.md)
git mv SOVEREIGN_LORE_CODEX_V1.md docs/vision/
git mv AGENTS.md docs/architecture/
git mv STATUS.md docs/operations/
# ... etc

# Result: 4-5 markdown files at root
```

---

## 🎯 Target Root Structure (After Full Cleanup)

```
/
├── README.md                    # Civilization Engine vision
├── GETTING_STARTED.md           # 5-minute quick start
├── CONTRIBUTING.md              # How to contribute
├── CHANGELOG.md                 # Version history
├── SECURITY.md                  # Security policy
│
├── docs/                        # All documentation (organized)
├── services/                    # Service code
├── k8s/                         # Kubernetes configs
├── ops/                         # Operational tools
├── cli/                         # CLI tool
├── src/                         # Core libraries
├── tests/                       # Test suites
├── schemas/                     # JSON schemas
├── examples/                    # Example configs
├── generators/                  # Code generators
├── sim/                         # Simulations
├── archive/                     # Historical records
└── [config files: package.json, .gitignore, etc]
```

**Markdown at Root:** 4-5 files (down from 23)
**Everything Else:** Organized in clear hierarchy

---

## 📈 Progress Tracking

| Stage | Files | Status |
|-------|-------|--------|
| **Start** | 25+ MD files at root | 📊 Baseline |
| **After Phase VI PR** | 25 MD files | 🔴 Same |
| **After GCP PR** | 25 MD files | �� Same |
| **After IDE Cleanup** | 23 MD files | 🟡 Better |
| **After Restructure** | 4-5 MD files | ✅ Target |

---

## ⚠️  Decision Required: vaultmesh-us-mcp/

**Current Status:** Untracked directory at root

**Options:**
1. **Move to services/** - If it's an active service
2. **Add to .gitignore** - If it's a separate repo/project
3. **Archive** - If it's obsolete
4. **Delete** - If it's temporary

**Question:** What is `vaultmesh-us-mcp/`? Is it:
- A separate project?
- An MCP server implementation?
- Temporary exploration code?

---

## ⚠️  Decision Required: sim/ai-mesh/

**Current Status:** Untracked directory at root

**Options:**
1. **Keep in sim/** - If it follows sim/ patterns (generators, outputs in out/)
2. **Move to services/** - If it's a service
3. **Delete** - If it's temporary exploration

---

## 🔒 Security Status

### ✅ Fixed This Session
- Removed hardcoded Cloudflare API token
- Updated .gitignore for credentials
- Created incident report

### ⚠️  Pending User Action
- **MUST rotate Cloudflare API token immediately**
- Token exposed in git history and PR #19 for ~30 minutes

### 🔮 Future Prevention
- Add secret scanning pre-commit hooks
- CI/CD credential detection
- Use SOPS for encrypted secrets (already configured in `.sops.yaml`)

---

## 📝 Summary

**Completed:**
- ✅ 24 files removed/archived
- ✅ IDE directories removed from git
- ✅ Security issue fixed
- ✅ `.gitignore` updated

**Remaining:**
- 📋 23 markdown files at root (need restructure in PR #20)
- 📋 Untracked directories need decisions (vaultmesh-us-mcp, sim/ai-mesh)
- ⚠️  Cloudflare token rotation (urgent user action)

**Next PR (#20):**
- Documentation restructure
- Move 18 markdown files to docs/ structure
- Result: 4-5 files at root

---

**The Remembrancer remembers:** Even cleanup is institutional knowledge.

🜂 **Solve et Coagula**
