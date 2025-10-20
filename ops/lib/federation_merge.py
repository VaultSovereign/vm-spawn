#!/usr/bin/env python3
"""
VaultMesh Federation Merge (Phase I)
- JCS-like canonical JSON (sorted keys, RFC8259 minimal separators)
- Deterministic union: sort by (event_hash asc, timestamp asc, signer_pubkey asc)
- Idempotent: dedupe by stable event_id
"""
import argparse, json, hashlib, time, sys, os

def canonical(obj) -> str:
    # JCS-compatible enough for Phase I: sorted keys, minimal whitespace.
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))

def event_hash(ev) -> str:
    return hashlib.sha256(canonical(ev).encode("utf-8")).hexdigest()

def deterministic_merge(left, right):
    by_id = {}
    for ev in left + right:
        eid = ev.get("event_id") or event_hash(ev)
        if eid not in by_id:
            by_id[eid] = ev
        else:
            # if different canonical hash with same id, prefer lowest hash (stable tie-break)
            old = by_id[eid]
            if event_hash(ev) < event_hash(old):
                by_id[eid] = ev
    events = list(by_id.values())
    events.sort(key=lambda e: (event_hash(e), e.get("timestamp",""), e.get("signer_pubkey","")))
    return events

def merkle_root(items):
    """Simple SHA256 Merkle over canonical(event) leaves."""
    leaves = [hashlib.sha256(canonical(i).encode("utf-8")).digest() for i in items]
    if not leaves:
        return hashlib.sha256(b"").hexdigest()
    level = leaves
    while len(level) > 1:
        it = iter(level)
        nxt = []
        for a in it:
            b = next(it, a)
            nxt.append(hashlib.sha256(a + b).digest())
        level = nxt
    return level[0].hex()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--left")
    ap.add_argument("--right")
    ap.add_argument("--out")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        a=[{"event_id":"1","timestamp":"2025-10-19","signer_pubkey":"A","payload":"x"}]
        b=[{"event_id":"2","timestamp":"2025-10-19","signer_pubkey":"B","payload":"y"}]
        merged=deterministic_merge(a,b)
        root=merkle_root(merged)
        print("MERGE_ROOT", root)
        return 0

    with open(args.left) as f: left=json.load(f)
    with open(args.right) as f: right=json.load(f)
    merged = deterministic_merge(left, right)
    root = merkle_root(merged)
    receipt = {
        "merge": {
            "left_head": merkle_root(left),
            "right_head": merkle_root(right),
            "merged_head": root,
            "events_replayed": len(merged),
            "policy": "jcs-canonical-union-v1",
            "sort_order": "event_hash asc, timestamp asc, signer_pubkey asc",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "trust_anchors": [],
        }
    }
    out = args.out or "ops/receipts/merge/merge.receipt"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f: f.write(canonical(receipt))
    print(root)
    return 0

if __name__ == "__main__":
    sys.exit(main())

