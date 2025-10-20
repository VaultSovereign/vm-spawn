# VaultMesh Federation Semantics — Phase I

**Goal:** deterministic, canonical, idempotent merge across peers.

## Event Canon
- **Canonical form:** JSON with sorted keys, minimal separators (JCS-like).
- **Event id:** `event_id` (recommended) else `sha256(canonical(event))`.
- **Deduplication:** by `event_id`.

## Merge Policy
```
ORDER BY event_hash ASC, timestamp ASC, signer_pubkey ASC
```
- Tie-breakers ensure stability across peers.

## Merkle
- Leaves: `sha256(canonical(event))`
- Pairing: left+right (duplicate last if odd)
- Root published in receipts, compared during `verify-audit`.

## MERGE_RECEIPT
```yaml
merge:
  left_head: <hash>
  right_head: <hash>
  merged_head: <hash>
  events_replayed: <N>
  policy: "jcs-canonical-union-v1"
  sort_order: "event_hash asc, timestamp asc, signer_pubkey asc"
  operator_sig: <optional gpg signature>
  merkle_root: <root_after_merge>
  timestamp: <iso-utc>
  trust_anchors: [<pubkey_fps>]
```

## Phase II (outline)
- Operator-signed `MERGE_RECEIPT`
- Anchor receipts to chain
- CRDT/Raft transport

