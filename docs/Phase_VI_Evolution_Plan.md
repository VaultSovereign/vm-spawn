# VaultMesh Phase VI Evolution Plan

## Overview

Phase VI introduces the federation hardening and deterministic anchoring flows that the
VaultMesh roadmap committed to following the successful completion of Phase V. The
objectives for this phase are:

- Provide a unified operator experience through the `vm` CLI.
- Ship the canonical receipt schemas and manifest definitions.
- Deliver the observability and operational playbooks required for 24/7 anchoring.
- Harden federation rollouts with explicit kill-switch and guard-rail wiring.

## Deliverables

### Unified CLI
- **Command grammar**: `vm <domain> <verb>` with nouns for `spawn`, `memory`, `audit`,
  `status`, and `configure`.
- **Profiles**: Operators can target multiple environments using the `--profile` flag.
- **Formats**: JSON is the default, with support for table output for human inspection.
- **Backwards compatibility**: Legacy shell tooling (`spawn.sh`, `ops/bin/remembrancer`,
  `ops/bin/health-check`) remains invocable via the CLI until the dedicated services land.

### Receipt & Batch Schema
- Receipt schema frozen at **version 1**.
- Batch manifest references receipt schema and enables deterministic replay.
- Schemas committed in `schemas/receipt.v1.json` and `schemas/batch-manifest.v1.json`.

### Phase VI Operations Pack
- Systemd user units for harbinger, sealer, anchor manager, and federation timers.
- Docker Compose spec for Redis anchoring cache.
- Example configuration for the guardian and federation peers.
- Verification script for anchors.

### Metrics & Kill Switches
- HTTP `/metrics` endpoint exposing `vaultmesh_anchor_verify_ok_total`,
  `vaultmesh_anchor_verify_fail_total`, and
  `vaultmesh_conflict_resolved_total` counters.
- Environment flags `FEDERATION_ENABLED`, `ANCHOR_WRITE_ENABLED`, and `VERIFY_ENFORCE`
  wired through services and systemd overrides.

## Milestones

1. **Week 1** – Land CLI foundation, schemas, and operations pack (this change set).
2. **Week 2** – Wire metrics export and integrate receipt validation in CI.
3. **Week 3** – Deliver deterministic conflict resolver and document kill-switch SOPs.
4. **Week 4** – Conduct end-to-end rehearsal using Phase VI compose and systemd assets.

## Operator Checklist

- Install the `vm` CLI and run `vm status show --format table` to verify environment.
- Populate `~/.vaultmesh/config.toml` using `vm configure`.
- Deploy supporting services with `systemctl --user enable --now` for each Phase VI unit.
- Run `ops/phase-vi/scripts/verify-anchor.sh` after each anchor cycle.

## Change Control

This document tracks the execution of Phase VI and must be updated alongside any
material alteration to the CLI, schemas, or operational assets. Changes require approval
from the federation guardians and must include updated receipt fixtures.
