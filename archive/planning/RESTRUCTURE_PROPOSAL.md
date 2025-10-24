# VaultMesh Documentation Restructure Proposal

**Vision:** "We don't just build your infrastructure - we evolve your organization into a digital civilization that gets smarter with every decision, never forgets institutional knowledge, and automatically optimizes itself across any cloud provider."

---

## Current Problem: Document Drift

- **25 markdown files at root** (9,264 lines)
- Mix of planning, status, completed work, operational guides
- No clear hierarchy or discovery path
- Multiple "truth" sources causing confusion

---

## Proposed Structure: Digital Civilization Framework

```
/
├── README.md                          # Main entry: The vision
├── GETTING_STARTED.md                 # Quick start for new contributors
├── CONTRIBUTING.md                    # How to contribute
├── CHANGELOG.md                       # Version history
│
├── docs/
│   ├── vision/                        # 🧠 The "Why"
│   │   ├── DIGITAL_CIVILIZATION.md    # Core vision statement
│   │   ├── PHILOSOPHY.md              # Alchemical/sovereignty philosophy
│   │   └── SOVEREIGN_LORE_CODEX.md    # Moved from root
│   │
│   ├── architecture/                  # 🏗️ The "What"
│   │   ├── OVERVIEW.md                # System architecture
│   │   ├── SERVICES.md                # Service catalog
│   │   ├── MEMORY_LAYER.md            # Institutional knowledge (remembrancer)
│   │   ├── INTELLIGENCE_LAYER.md      # AI/optimization layer
│   │   └── EVOLUTION_LAYER.md         # Self-optimization mechanisms
│   │
│   ├── guides/                        # 📚 The "How"
│   │   ├── operators/                 # For platform operators
│   │   │   ├── DEPLOYMENT.md          # General deployment guide
│   │   │   ├── GCP_DEPLOYMENT.md      # GCP-specific
│   │   │   ├── AWS_DEPLOYMENT.md      # AWS-specific
│   │   │   └── MONITORING.md          # Observability
│   │   │
│   │   ├── developers/                # For service developers
│   │   │   ├── CLI_REFERENCE.md       # `vm` command reference
│   │   │   ├── SPAWN_SERVICES.md      # Creating new services
│   │   │   ├── AGENTS.md              # Moved from root
│   │   │   └── AI_AGENTS.md           # AI agent development
│   │   │
│   │   └── users/                     # For end users
│   │       ├── ANALYTICS.md           # Using VaultMesh Analytics
│   │       └── API_REFERENCE.md       # API documentation
│   │
│   ├── operations/                    # 🔧 Operational runbooks
│   │   ├── STATUS.md                  # Current deployment status
│   │   ├── RUNBOOKS.md                # Common procedures
│   │   ├── TROUBLESHOOTING.md         # Known issues & fixes
│   │   └── COST_OPTIMIZATION.md       # Cost management
│   │
│   └── evolution/                     # 🚀 The "What's Next"
│       ├── ROADMAP.md                 # Product roadmap
│       ├── PHASE_VI.md                # Current phase
│       ├── PROPOSALS.md               # Enhancement proposals
│       └── EXPERIMENTS.md             # Experimental features
│
├── archive/                           # 📦 Historical records
│   ├── deployments/                   # Old deployment records
│   │   └── 2025-10-23/                # Date-stamped
│   ├── planning/                      # Old planning docs
│   └── audits/                        # Code/infra audits
│
└── [services/k8s/ops/etc remain as-is]
```

---

## Migration Plan

### Phase 1: Core Structure (Immediate)
Move root docs to aligned locations:

**Vision Layer:**
- `SOVEREIGN_LORE_CODEX_V1.md` → `docs/vision/SOVEREIGN_LORE_CODEX.md`
- Create `docs/vision/DIGITAL_CIVILIZATION.md` (new - core vision)
- `PROPOSAL_9_9_EXCELLENCE.md` → `docs/vision/PHILOSOPHY.md`

**Architecture Layer:**
- `AGENTS.md` → `docs/architecture/INTELLIGENCE_LAYER.md`
- Create `docs/architecture/MEMORY_LAYER.md` (remembrancer, receipts, anchoring)
- Create `docs/architecture/EVOLUTION_LAYER.md` (KEDA, feature flags, optimization)

**Guides Layer:**
- `GCP_DEPLOYMENT_STATUS.md` → `docs/guides/operators/GCP_DEPLOYMENT.md`
- `GCP_COST_COMPARISON.md` → `docs/operations/COST_OPTIMIZATION.md`
- `GETTING_STARTED_AURORA_ROUTER.md` → `docs/guides/developers/AURORA_ROUTER.md`
- `VAULTMESH_ANALYTICS_STATUS.md` → `docs/guides/users/ANALYTICS.md`
- `AI_AGENT_QUICKSTART.md` → `docs/guides/developers/AI_AGENTS.md`

**Operations Layer:**
- `STATUS.md` → `docs/operations/STATUS.md`
- `DEPLOYMENT_COMPLETE_100_PERCENT.md` → `archive/deployments/2025-10-23/`
- `KPI_DEPLOYMENT_FINAL_STATUS.md` → `archive/deployments/2025-10-23/`

**Evolution Layer:**
- `PRODUCTION_ROUTER_ROADMAP.md` → `docs/evolution/ROADMAP.md`
- `Phase_VI_Evolution_Plan (1).md` → `docs/evolution/PHASE_VI.md`
- `EXPERIMENTAL_SERVICES.md` → `docs/evolution/EXPERIMENTS.md`

**Archive:**
- `CODE_AUDIT_2025_10_24.md` → `archive/audits/2025-10-24/`
- `CLEANUP_GCP_DOCS_2025-10-24.md` → `archive/planning/`
- `CLEANUP_PLAN.md` → `archive/planning/`
- `EXECUTION_STATUS.md` → `archive/deployments/`

### Phase 2: Content Alignment (Next PR)
- Update each doc to align with vision language
- Add cross-references between layers
- Create navigation guides
- Update README.md with new structure

### Phase 3: Automation (Future)
- CI check: no markdown at root except README/CHANGELOG/CONTRIBUTING
- Auto-generate table of contents
- Link checking
- Documentation versioning

---

## Immediate Next Steps

### PR #1: GCP Deployment + Analytics (Next)
```bash
feat(infra): deploy GCP infrastructure and analytics UI

- GKE Autopilot deployment (vm-spawn project)
- VaultMesh Analytics (Next.js dashboard)
- Aurora Router service
- Cloudflare DNS integration
- LoadBalancer + Ingress configuration
```

### PR #2: Documentation Restructure (Following)
```bash
docs: restructure to digital civilization framework

Align documentation with VaultMesh vision:
- Memory layer (institutional knowledge)
- Intelligence layer (AI/optimization)
- Evolution layer (self-improvement)
- Clear operator/developer/user guides
```

---

## Benefits

**Discovery:**
- Clear path from vision → architecture → guides
- Role-based documentation (operator/developer/user)
- Easy to find current status vs future plans

**Clarity:**
- One source of truth per topic
- Vision-aligned language throughout
- Historical context preserved in archive

**Evolution:**
- New features map to layers
- Roadmap clearly shows "what's next"
- Experimental work isolated

**Maintenance:**
- No more root-level drift
- Clear ownership boundaries
- Automated checks prevent regression

---

## Vision Mapping

| Layer | Purpose | Current Docs | Principle |
|-------|---------|--------------|-----------|
| **Vision** | Why we exist | Philosophy, lore | "Digital civilization" |
| **Architecture** | What we are | Service designs | "Never forgets" |
| **Guides** | How to use it | Tutorials, API | "Gets smarter" |
| **Operations** | How we run | Status, runbooks | "Self-optimizes" |
| **Evolution** | Where we're going | Roadmap, experiments | "Any cloud provider" |

---

## Root Directory (Clean)

After restructure:
```
/
├── README.md          # Vision + Quick navigation
├── GETTING_STARTED.md # 5-minute start
├── CONTRIBUTING.md    # How to contribute
├── CHANGELOG.md       # Version history
├── docs/              # All documentation
├── services/          # Service code
├── k8s/              # Kubernetes configs
├── ops/              # Operational tools
└── archive/          # Historical records
```

**Result:** 4 markdown files at root (down from 25), clear hierarchy, vision-aligned

---

**Question:** Should we proceed with this restructure in the next PR after GCP deployment?
