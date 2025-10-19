#!/usr/bin/env python3
"""
Federation Sync (HTTP MCP)
Pull remote memory IDs, compute missing IDs, fetch & validate, insert locally.
No external deps: uses simple HTTP POST to /mcp.
"""
from __future__ import annotations
import json, os, sqlite3, sys, urllib.request
from typing import Dict, Any, List

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DB   = os.path.join(ROOT, "ops", "data", "remembrancer.db")

def mcp_tool(url: str, name: str, args: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """Call MCP tool via JSON-RPC over HTTP POST"""
    payload = {"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":name,"arguments":args or {}}}
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"),
                                 headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            res = json.loads(resp.read().decode("utf-8"))
            # Handle both direct result and nested result
            if "result" in res:
                result = res["result"]
                # Some MCP servers wrap the content further
                if isinstance(result, dict) and "content" in result:
                    return result["content"][0] if isinstance(result["content"], list) else result["content"]
                return result
            return res
    except Exception as e:
        return {"ok": False, "error": str(e)}

def local_ids(limit: int = 100000) -> List[str]:
    """Get list of local memory IDs from SQLite"""
    if not os.path.isfile(DB):
        return []
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT id FROM memories ORDER BY timestamp,id LIMIT ?", (limit,))
    ids = [r["id"] for r in cur.fetchall()]
    conn.close()
    return ids

def insert_memory(mem: Dict[str, Any]) -> None:
    """Insert or replace memory in local SQLite"""
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    conn = sqlite3.connect(DB)
    # Ensure table exists
    conn.execute("""
        CREATE TABLE IF NOT EXISTS memories (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          type TEXT NOT NULL,
          component TEXT,
          version TEXT,
          hash TEXT,
          sig TEXT,
          data JSON,
          merkle_root TEXT
        )
    """)
    cur = conn.cursor()
    cur.execute("""
        INSERT OR REPLACE INTO memories (id,timestamp,type,component,version,hash,sig,data,merkle_root)
        VALUES (?,?,?,?,?,?,?,?,?)
    """, (mem.get("id"), mem.get("timestamp"), mem.get("type"), mem.get("component"),
          mem.get("version"), mem.get("hash"), mem.get("sig"), 
          json.dumps(mem.get("data")) if mem.get("data") else None, 
          mem.get("merkle_root")))
    conn.commit()
    conn.close()

def main():
    if len(sys.argv) < 2:
        print("Usage: federation_sync.py <peer_mcp_http_url>")
        print("Example: federation_sync.py http://peer:8001/mcp")
        sys.exit(1)
    peer = sys.argv[1]

    print(f"→ Syncing from {peer}")
    
    # 1) Get remote IDs
    print("  → Fetching remote memory IDs...")
    remote = mcp_tool(peer, "list_memory_ids", {})
    if not remote.get("ok"):
        print(f"❌ Remote error: {remote}")
        sys.exit(2)
    r_ids = remote.get("ids", [])
    print(f"  → Remote has {len(r_ids)} memories")
    
    # 2) Get local IDs
    l_ids = local_ids()
    print(f"  → Local has {len(l_ids)} memories")
    
    # 3) Compute missing (remote - local)
    missing = [mid for mid in r_ids if mid not in set(l_ids)]
    print(f"  → Missing from local: {len(missing)}")
    
    if not missing:
        print("✅ Already in sync")
        return
    
    # 4) Fetch & insert
    success = 0
    failed = 0
    for mid in missing:
        mem_result = mcp_tool(peer, "get_memory", {"memory_id": mid})
        if not mem_result.get("ok"):
            print(f"  ⚠️  Fetch failed for {mid}: {mem_result.get('error')}")
            failed += 1
            continue
        try:
            insert_memory(mem_result["memory"])
            success += 1
        except Exception as e:
            print(f"  ⚠️  Insert failed for {mid}: {e}")
            failed += 1
    
    print(f"✅ Sync complete: {success} inserted, {failed} failed")

if __name__ == "__main__":
    main()

