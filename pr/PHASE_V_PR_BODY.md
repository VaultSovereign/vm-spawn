# feat(remembrancer/federation): Phase V — Anchor Federation & Peer Governance

## Summary
Adds peer-to-peer replication for sealed batches and anchors with local re-verification, deterministic
conflict resolution, anti-entropy range sync, and governance-controlled peer routing.

See:
- `docs/FEDERATION_PROTOCOL.md`
- `docs/FEDERATION_OPERATIONS.md`
- `docs/REMEMBRANCER_PHASE_V.md`

## New
- `services/federation/` daemon (HTTP endpoints + gossip broadcast)
- `vmsh/config/federation.yaml`, `vmsh/config/peers.yaml`
- `tools/vmsh-federation.ts` CLI
- Makefile targets: `federation`, `federation-status`, `federation-sync`

## Test Plan
1. Start Scheduler & Sealer; produce at least one batch.
2. Run `make federation` on Node A.
3. On Node B (with different `node_id`), run `make federation` and `federation-status`.
4. Submit new events on A → seal → anchor; A will announce; B can request bundle and import.
5. Run `make verify-online` on B to confirm anchors pass with local policies.

## Rollout Notes
- Peer admission via DID allowlist (`peers.yaml`).
- Confirmation thresholds inherited from `anchors.yaml`.
- All imports maintain provenance; superseded anchors are retained with memo references.
