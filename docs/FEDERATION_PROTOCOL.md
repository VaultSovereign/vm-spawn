# VaultMesh Federation Protocol (Phase V)

This document defines the **wire messages**, **auth model**, and **conflict rules** for Remembrancer federation.

## Messages
- **Announce**: `{ namespace, batchId, batchRoot, anchors[], ts, signer }`
- **Request**: `{ namespace, fromTs?, toTs?, want?, ts, signer }`
- **Bundle**: `{ receipts[], anchors[], ts, signer }`

All messages are **JCS canonicalized** and **signed** (future: DID signatures).

## Conflict Resolution
1. Prefer higher finality: `btc:* > eip155:* > rfc3161:*`.
2. Same rail: higher `block` height wins.
3. Tie-break: lexicographic `(chain, tx)`.

## Anti-Entropy
Nodes periodically compare ranges and request missing receipts by time or batch id.

## Security
- Peer allowlist via `peers.yaml` (DID and role).
- Rate limits per namespace.
- All imports re-verified locally using EVM/BTC/TSA verifiers.
