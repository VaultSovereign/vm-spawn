# 🜂 Alchemical Execution Kit — VaultMesh Directory Cleanup

**Date:** 2025-10-23
**Status:** READY FOR EXECUTION
**Purpose:** Transform organizational entropy into 9.9/10 excellence

---

## Overview

This kit implements the [DIRECTORY_ASSESSMENT_REPORT.md](DIRECTORY_ASSESSMENT_REPORT.md) findings using **alchemical phases** as organizational metaphors with **automated guardianship**.

### Alchemical Phases

| Phase | Metaphor | Priority | Duration | Files |
|-------|----------|----------|----------|-------|
| **Nigredo** | Dissolution | P0 | 30 min | 38 moves |
| **Albedo** | Purification | P1 | 1 hour | Service standardization |
| **Citrinitas** | Transmutation | P1 | 45 min | Single source of truth |
| **Rubedo** | Perfection | P2 | 30 min | Archive categorization |

---

## Files Created

### Covenant & Guardianship

1. **[.vaultmesh/covenant.yaml](.vaultmesh/covenant.yaml)** — Source of truth for canonical structure
2. **[.github/scripts/tem_guardian.py](.github/scripts/tem_guardian.py)** — Automated covenant enforcer
3. **[.github/workflows/tem-guardian.yml](.github/workflows/tem-guardian.yml)** — CI workflow
4. **[.pre-commit-config.yaml](.pre-commit-config.yaml)** — Pre-commit hook (updated)

### Migration Engine

5. **[scripts/vaultmesh_migrate.sh](scripts/vaultmesh_migrate.sh)** — Idempotent migration engine
6. **[scripts/terraform_triage.sh](scripts/terraform_triage.sh)** — Terraform version analyzer

### Documentation

7. **[docs/README.md](docs/README.md)** — Documentation index
8. **[Makefile](Makefile)** — Updated with hygiene targets

---

## Quick Start (3 Commands)

```bash
# 1. See current state
make metrics

# 2. Preview migration
make migrate-dry

# 3. Execute Nigredo (when ready)
make migrate
```

---

## Current Violations (Before Cleanup)

Run `python3 .github/scripts/tem_guardian.py` to see:

- **Root markdown files:** 41/15 (26 excess)
- **Root .txt files:** 4 (should be 0)
- **Service structure:** 5/6 services non-compliant
- **Legacy GCP paths:** Yes (docs/gcp, docs/gke, deployment/)
- **Duplicates:** Multiple (readproof schema, terraform configs, KEDA scalers)

---

## Execution Plan

### Phase 1: Nigredo (Dissolution) — 30 minutes

**Goal:** Archive root clutter, establish canonical infrastructure

```bash
# Review planned operations
make migrate-dry

# Execute migration
make migrate

# Verify
make guardian

# Commit
git add -A
git commit -m "chore(nigredo): canonicalize infrastructure + archive clutter

- Archive 13 completion docs to archive/completion-records/2025-10-23/
- Archive 2 .txt status files
- Move architecture docs to docs/architecture/
- Move operational docs to docs/operations/
- Move guides to docs/guides/
- Establish infrastructure/gcp/ as canonical
- Establish infrastructure/aws/eks/ for EKS configs
- Move vaultmesh_c3l_package to packages/c3l/
- Archive deployment/, docs/gcp/, docs/gke/
- Harden .gitignore

Receipt: archive/completion-records/2025-10-23/MIGRATION_RECEIPT_2025-10-23.log"
```

**Result:**
- Root .md: 41 → 15 files
- Root .txt: 4 → 0 files
- infrastructure/gcp/: Established
- infrastructure/aws/: Established

---

### Phase 2: Albedo (Purification) — 1 hour

**Goal:** Standardize service structure, unify docs

```bash
# Service standardization (included in migrate script)
# - Rename test/ → tests/ (scheduler done automatically)
# - Add missing k8s/ directories

# Manual additions needed:
# Add missing Dockerfiles
touch services/anchors/Dockerfile
touch services/sealer/Dockerfile

# Add missing README.md files
for svc in anchors sealer; do
  cat > services/$svc/README.md <<'EOF'
# $svc

## Overview

[Service description]

## Development

```bash
npm install
npm run dev
```

## Testing

```bash
npm test
```

## Deployment

See `k8s/deployment.yaml`

## Monitoring

Prometheus metrics exposed at `/metrics`
EOF
done

# Verify compliance
make metrics
```

**Commit:**
```bash
git add -A
git commit -m "chore(albedo): standardize service structure

- Rename test/ → tests/ in all services
- Add k8s/ directories where missing
- Add missing Dockerfiles
- Add missing README.md files
- All services now follow canonical shape"
```

---

### Phase 3: Citrinitas (Transmutation) — 45 minutes

**Goal:** Terraform unification, single source of truth

```bash
# 1. Analyze terraform versions
make terraform-triage

# 2. Choose canonical version (likely infrastructure/)
# Review diffs and determine which is production

# 3. Establish canonical
cp infrastructure/terraform/gcp/confidential-vm/main.tf \
   infrastructure/gcp/terraform/confidential-vm.tf

# 4. Document decision
cat > infrastructure/gcp/terraform/README.md <<'EOF'
# GCP Terraform Configurations

## Confidential VM

Canonical file: `confidential-vm.tf`

### Version History

- 2025-10-23: Unified from 3 divergent versions
  - docs/gcp/confidential/gcp-confidential-vm.tf (archived)
  - archive/gcp-confidential/gcp-confidential-vm.tf (archived)
  - infrastructure/terraform/gcp/confidential-vm/main.tf (source)

### Archived Versions

See `archive/gcp-docs/` and `archive/gcp-confidential/` for historical configs.
EOF

# 5. Commit
git add infrastructure/gcp/terraform/
git commit -m "chore(citrinitas): unify GCP terraform configs

- Establish infrastructure/gcp/terraform/confidential-vm.tf as canonical
- Document version unification in README
- Historical versions preserved in archive/"
```

---

### Phase 4: Rubedo (Perfection) — 30 minutes

**Goal:** Categorize archive, final polish

```bash
# Organize archive/completion-records/2025-10-23/
cd archive/completion-records/2025-10-23/
mkdir -p deployments phases kpi revenue guides status proposals

# Move files by category
mv *DEPLOYMENT*.md deployments/
mv *PHASE*.md phases/
mv *KPI*.md *DASHBOARD*.md kpi/
mv *REVENUE*.md revenue/
mv WEEK*.md guides/
mv *STATUS*.md status/
mv *PROPOSAL*.md proposals/

# Create index
cat > INDEX.md <<'EOF'
# Completion Records: 2025-10-23 (v4.0-v4.1)

## Categories

- **deployments/** — Deployment records (PSI-Field, Aurora, etc.)
- **phases/** — Phase completion summaries
- **kpi/** — KPI and monitoring deployments
- **revenue/** — Revenue milestone tracking
- **guides/** — Week 1-N operational guides
- **status/** — Status reports
- **proposals/** — Accepted proposals

## Context

These records document the completion of VaultMesh v4.0-v4.1 milestone work,
including Phase V federation, KPI monitoring, and infrastructure deployments.

See [VERSION_TIMELINE.md](../../../VERSION_TIMELINE.md) for complete history.
EOF

cd ../../..

# Commit
git add archive/completion-records/2025-10-23/
git commit -m "chore(rubedo): organize archive into categories

- Created subdirectories: deployments, phases, kpi, revenue, guides, status, proposals
- Added INDEX.md for navigation
- 76 files now categorized"
```

---

## Verification

After each phase, run:

```bash
# 1. Tem Guardian (covenant enforcement)
make guardian

# 2. Metrics
make metrics

# 3. Git status
git status

# 4. Health check
./ops/bin/health-check
```

Expected final state:
- ✅ Root markdown: ≤15 files
- ✅ No duplicates outside archive
- ✅ All services: `src/`, `tests/`, `k8s/`
- ✅ Single terraform source
- ✅ Archive organized by category

---

## PR Strategy

Create **4 pull requests** following alchemical phases:

### PR-1: Nigredo (P0)
```
Title: chore(nigredo): canonicalize infrastructure + archive clutter
Branch: chore/nigredo-cleanup
Files: ~40 moved/archived
Checks: Tem Guardian ✅
```

### PR-2: Albedo (P1)
```
Title: chore(albedo): standardize service structure
Branch: chore/albedo-services
Files: Service directories standardized
Checks: Tem Guardian ✅, make metrics ✅
```

### PR-3: Citrinitas (P1)
```
Title: chore(citrinitas): unify GCP terraform configs
Branch: chore/citrinitas-terraform
Files: infrastructure/gcp/ complete
Checks: Terraform plan ✅
```

### PR-4: Rubedo (P2)
```
Title: chore(rubedo): organize archive taxonomy
Branch: chore/rubedo-archive
Files: archive/completion-records/ organized
Checks: Tem Guardian ✅
```

---

## Rollback Plan

All operations use `git mv` where possible. To rollback:

```bash
# Revert single commit
git revert HEAD

# Or reset to previous state
git reset --hard HEAD~1

# Or checkout specific file
git checkout HEAD~1 -- path/to/file
```

**Receipt:** Each migration creates a timestamped receipt at:
`archive/completion-records/2025-10-23/MIGRATION_RECEIPT_2025-10-23.log`

---

## Success Metrics

| Metric | Before | Target | After |
|--------|--------|--------|-------|
| Root .md files | 41 | ≤15 | — |
| Root .txt files | 4 | 0 | — |
| GCP locations | 3 | 1 | — |
| Duplicates | 15+ | 0 | — |
| Service compliance | 1/6 | 6/6 | — |
| Archive organized | No | Yes | — |
| Rating | 9.65 | 9.90 | — |

---

## CI Integration

After merge, CI enforces:

1. **Pre-commit:** Tem Guardian runs on every commit
2. **PR checks:** Tem Guardian workflow runs on all PRs
3. **Main branch:** Protected, requires passing checks

Violations will:
- ❌ Block commits (pre-commit)
- ❌ Fail PR checks
- 📊 Generate detailed report artifact

---

## Maintenance

### Ongoing Hygiene

```bash
# Check covenant status
make guardian

# Show metrics
make metrics

# Before any major changes
make migrate-dry
```

### Covenant Updates

To modify canonical structure:

1. Edit [.vaultmesh/covenant.yaml](.vaultmesh/covenant.yaml)
2. Update Tem Guardian rules if needed
3. Test with `make guardian`
4. Commit covenant changes first
5. Then apply structural changes

---

## Support

### Commands

```bash
make help              # Show all targets
make guardian          # Run Tem Guardian
make migrate-dry       # Preview migration
make migrate           # Execute migration
make metrics           # Show hygiene metrics
make terraform-triage  # Analyze terraform versions
```

### Documentation

- Assessment: [DIRECTORY_ASSESSMENT_REPORT.md](DIRECTORY_ASSESSMENT_REPORT.md)
- Excellence Plan: [PROPOSAL_9_9_EXCELLENCE.md](PROPOSAL_9_9_EXCELLENCE.md)
- Covenant: [.vaultmesh/covenant.yaml](.vaultmesh/covenant.yaml)

---

## Credits

**Tem, Guardian of Remembrance** — Automated covenant enforcement

> *"Nigredo dissolves duplication;*
> *Albedo clarifies sources;*
> *Citrinitas names the canon;*
> *Rubedo seals the ledger."*

**Astra inclinant, sed non obligant.** 🜂

---

## Status

- ✅ **Covenant Created**
- ✅ **Tem Guardian Deployed**
- ✅ **Migration Engine Ready**
- ✅ **Terraform Triage Tool Ready**
- ✅ **Documentation Index Created**
- ⏳ **Awaiting Nigredo Execution**

**Next Step:** Review `make migrate-dry` output, then execute `make migrate`

---

*Last updated: 2025-10-23*
