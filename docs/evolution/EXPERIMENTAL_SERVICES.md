# Experimental Services (Not Yet in Production)

**Status:** 🔬 Experimental / Research
**Date:** 2025-10-23

---

## Overview

This document tracks experimental services and features that are **not part of the current production deployment**. These are research projects, prototypes, or future enhancements.

**Current Deployment Includes:**
- ✅ Psi-Field (dual backend)
- ✅ Scheduler (10/10 production-hardened)
- ✅ Harbinger (Layer 3)
- ✅ Federation (Phase V)
- ✅ Anchors
- ✅ Sealer

**Not Yet Deployed (Experimental):**
- ⚗️ Aurora Router
- ⚗️ AI Mesh

---

## Experimental Services

### 1. Aurora Router

**Location:** [services/aurora-router/](services/aurora-router/)
**Status:** 🟡 In Development
**Purpose:** AI-enhanced multi-provider compute routing

**What it does:**
- Routes workloads across DePIN providers (Akash, io.net, Render, Flux, etc.)
- Uses AI agents for intelligent routing decisions
- Integrates with Ψ-Field for predictive routing

**Why not deployed yet:**
- Still in development
- Requires additional provider integrations
- Not yet production-tested

**Roadmap:** [PRODUCTION_ROUTER_ROADMAP.md](PRODUCTION_ROUTER_ROADMAP.md)

**To deploy:**
```bash
# NOT READY YET - In development
cd services/aurora-router
# See README.md for current status
```

---

### 2. AI Mesh

**Location:** [sim/ai-mesh/](sim/ai-mesh/)
**Status:** 🟡 Research / Training
**Purpose:** AI agent swarm for distributed workload optimization

**What it does:**
- Trains AI agents in simulation
- Multi-agent coordination for workload distribution
- Reinforcement learning for routing optimization

**Why not deployed yet:**
- Research phase
- Training/simulation only
- Not yet integrated with production services

**To use:**
```bash
cd sim/ai-mesh
python train.py  # Train agents
python swarm.py  # Run swarm simulation
```

**Integration path:**
- Phase 1: Complete training (current)
- Phase 2: Integrate with Aurora Router
- Phase 3: Deploy to production

---

## Simulators (Research Tools)

### Multi-Provider Routing Simulator

**Location:** [sim/multi-provider-routing-simulator/](sim/multi-provider-routing-simulator/)
**Status:** ✅ Active (research)
**Purpose:** Simulate routing strategies before production deployment

**Outputs:** CSV files in `sim/multi-provider-routing-simulator/out/` (ignored by git)

---

## When Will These Be Production-Ready?

### Aurora Router
- **Timeline:** 3-4 weeks
- **Blockers:** Provider adapters, production testing
- **Next steps:** See [PRODUCTION_ROUTER_ROADMAP.md](PRODUCTION_ROUTER_ROADMAP.md)

### AI Mesh
- **Timeline:** 4-6 weeks
- **Blockers:** Training completion, integration design
- **Next steps:** Complete agent training, design production integration

---

## Current Deployment (Stable Services)

For the **current GCP deployment**, we will deploy:

1. **Psi-Field** — Prediction service (dual backend)
2. **Scheduler** — Anchor scheduler (10/10 hardened)
3. **Harbinger** — Layer 3 orchestration (optional)
4. **Federation** — Peer-to-peer federation (optional)
5. **Monitoring** — Prometheus + Grafana

**Experimental services will NOT be deployed.**

---

## How to Track Progress

- Watch [PRODUCTION_ROUTER_ROADMAP.md](PRODUCTION_ROUTER_ROADMAP.md) for Aurora Router updates
- Check `services/aurora-router/README.md` for current status
- Check `sim/ai-mesh/README.md` for AI Mesh progress

---

## Summary

✅ **Production-ready:** Psi-Field, Scheduler, Harbinger, Federation
⚗️ **Experimental:** Aurora Router, AI Mesh
🔬 **Research:** Simulators, AI training

**For GCP deployment, we focus on production-ready services only.**
