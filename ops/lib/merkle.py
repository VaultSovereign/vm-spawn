#!/usr/bin/env python3
import argparse, hashlib, json, sqlite3, sys
from typing import List, Dict, Any

def leaf_hash(rec: Dict[str, Any]) -> str:
    """Deterministic leaf hash from a canonical JSON projection."""
    # Keep only stable fields; avoid volatile ones if any
    proj = {
        "id": rec.get("id"),
        "timestamp": rec.get("timestamp"),
        "type": rec.get("type"),
        "component": rec.get("component"),
        "version": rec.get("version"),
        "hash": rec.get("hash"),
        "sig": rec.get("sig"),
        "data": rec.get("data"),
    }
    blob = json.dumps(proj, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()

def merkle_root(leaves: List[str]) -> str:
    if not leaves:
        return ""
    level = leaves[:]
    while len(level) > 1:
        nxt = []
        for i in range(0, len(level), 2):
            a = level[i]
            b = level[i+1] if i+1 < len(level) else a
            nxt.append(hashlib.sha256((a + b).encode("utf-8")).hexdigest())
        level = nxt
    return level[0]

def from_sqlite(path: str) -> List[str]:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT id,timestamp,type,component,version,hash,sig,data FROM memories ORDER BY timestamp,id;")
    rows = cur.fetchall()
    conn.close()
    return [leaf_hash(dict(r)) for r in rows]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compute", action="store_true", help="Compute Merkle root")
    ap.add_argument("--from-sqlite", metavar="DB", help="SQLite DB path")
    ap.add_argument("--from-json", metavar="FILE", help="JSON array of records")
    args = ap.parse_args()

    if not args.compute:
        ap.error("--compute required")

    leaves: List[str] = []
    if args.from_sqlite:
        leaves = from_sqlite(args.from_sqlite)
    elif args.from_json:
        data = json.load(open(args.from_json, "r", encoding="utf-8"))
        leaves = [leaf_hash(rec) for rec in data]
    else:
        ap.error("Provide --from-sqlite or --from-json")

    print(merkle_root(leaves))

if __name__ == "__main__":
    main()

