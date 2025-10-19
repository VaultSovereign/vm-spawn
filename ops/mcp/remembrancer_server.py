#!/usr/bin/env python3
from __future__ import annotations
"""
Remembrancer MCP Server (v4.0 Kickoff)
- Wraps existing CLI ops/bin/remembrancer as MCP resources/tools/prompts.
- Supports stdio by default; optional HTTP if FASTMCP supports it.
"""
import asyncio, json, os, subprocess, sys
from typing import Any, Dict, List

try:
    # FastMCP is the official Python server SDK
    from mcp.server.fastmcp import FastMCP
except Exception:
    sys.stderr.write("FastMCP not available. Install via: pip install mcp\n")
    # Fail-soft: allow module import for non-MCP paths; only crash on run()
    FastMCP = None  # type: ignore

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REM  = os.path.join(ROOT, "ops", "bin", "remembrancer")
DB   = os.path.join(ROOT, "ops", "data", "remembrancer.db")

# Optional HTTP transport (disabled by default; enable by env)
STREAMABLE_HTTP = os.getenv("REMEMBRANCER_MCP_HTTP", "").lower() in ("1", "true", "yes")
if FastMCP:
    if STREAMABLE_HTTP:
        mcp = FastMCP("Remembrancer", streamable_http_path="/mcp")
    else:
        mcp = FastMCP("Remembrancer")
else:
    mcp = None  # type: ignore

def _run(cmd: List[str]) -> subprocess.CompletedProcess:
    if not os.path.isfile(REM):
        return subprocess.CompletedProcess(cmd, 127, "", f"remembrancer not found at {REM}")
    return subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, check=False)

# ------------------------------ Resources ------------------------------------
@mcp.resource("memory://local/{memory_id}")  # type: ignore
def memory_local(memory_id: str) -> str:
    # Minimal surface: delegate to CLI search or a direct DB query later
    # Here we return a JSON stub so the resource exists
    return json.dumps({"id": memory_id, "source": "local", "note": "MVP resource"})

@mcp.resource("adr://local/{year}/ADR-{num}")  # type: ignore
def adr_local(year: int, num: int) -> str:
    # Delegate to CLI in future; return ADR skeleton for now
    return f"# ADR-{num:03d} ({year})\nStatus: Proposed\nContext: …\nDecision: …\nConsequences: …\n"

@mcp.resource("receipt://deploy/{component}/{version}")  # type: ignore
def receipt_deploy(component: str, version: str) -> str:
    # In future: parse YAML receipt; MVP returns a stub
    return json.dumps({"component": component, "version": version, "receipt": "MVP stub"})

@mcp.resource("merkle://root")  # type: ignore
def merkle_root() -> str:
    # Compute via merkle.py if present; otherwise placeholder
    merkle_py = os.path.join(ROOT, "ops", "lib", "merkle.py")
    if os.path.isfile(merkle_py) and os.path.isfile(DB):
        p = _run([sys.executable, merkle_py, "--compute", "--from-sqlite", DB])
        if p.returncode == 0:
            return p.stdout.strip()
    return ""

# -------------------------------- Tools --------------------------------------
@mcp.tool()  # type: ignore
def search_memories(query: str, scope: str = "local", limit: int = 25) -> List[Dict[str, Any]]:
    """
    MVP: naive delegation not implemented; return a single stub match.
    Future: wire to CLI/SQLite FTS.
    """
    return [{"id": "mem:covenant/abc123", "title": f"Result for {query}", "score": 0.9}]

@mcp.tool()  # type: ignore
def verify_artifact(artifact_path: str) -> Dict[str, Any]:
    """
    Call 'remembrancer verify-full' and parse a coarse result.
    """
    if not os.path.isfile(artifact_path):
        return {"ok": False, "error": f"Not found: {artifact_path}"}
    p = _run([REM, "verify-full", artifact_path])
    ok = (p.returncode == 0)
    return {"ok": ok, "stdout": p.stdout, "stderr": p.stderr}

@mcp.tool()  # type: ignore
def sign_artifact(artifact_path: str, key_id: str) -> Dict[str, Any]:
    if not os.path.isfile(artifact_path):
        return {"ok": False, "error": f"Not found: {artifact_path}"}
    p = _run([REM, "sign", artifact_path, "--key", key_id])
    return {"ok": p.returncode == 0, "stdout": p.stdout, "stderr": p.stderr}

@mcp.tool()  # type: ignore
def record_decision(title: str, body: str, tags: List[str] | None = None, sign: bool = False) -> Dict[str, Any]:
    """
    MVP: Demonstrate invocation; wire to your real CLI subcommand later.
    """
    payload = {"title": title, "body": body, "tags": tags or [], "sign": sign}
    return {"ok": True, "recorded": payload}

# -------------------------------- Prompts ------------------------------------
@mcp.prompt()
def adr_template(title: str, context: str) -> str:
    return f"""You are the Remembrancer. Draft an ADR.
Title: {title}
Context:
{context}
Sections: Context, Decision, Consequences, Status=Proposed.
"""

@mcp.prompt()  # type: ignore
def deployment_postmortem(component: str, version: str) -> str:
    return f"""Create a deployment postmortem.
Component: {component}
Version: {version}
Include timeline, impact, root cause, and improvements."""

# ---------- Phase 3: Federation helpers ----------
@mcp.tool()  # type: ignore
def list_memory_ids(limit: int = 10000) -> Dict[str, Any]:
    """
    Return a list of local memory IDs stored by Remembrancer (via SQLite).
    MVP: read IDs if DB exists; else return empty.
    """
    ids: List[str] = []
    try:
        import sqlite3
        if os.path.isfile(DB):
            conn = sqlite3.connect(DB)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute("SELECT id FROM memories ORDER BY timestamp,id LIMIT ?", (limit,))
            ids = [r["id"] for r in cur.fetchall()]
            conn.close()
    except Exception as e:
        return {"ok": False, "error": str(e), "ids": []}
    return {"ok": True, "ids": ids}

@mcp.tool()  # type: ignore
def get_memory(memory_id: str) -> Dict[str, Any]:
    """
    Fetch a memory row by ID and return as dict (for federation sync).
    """
    try:
        import sqlite3
        if not os.path.isfile(DB):
            return {"ok": False, "error": "DB missing"}
        conn = sqlite3.connect(DB)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("SELECT id,timestamp,type,component,version,hash,sig,data,merkle_root FROM memories WHERE id=?",(memory_id,))
        row = cur.fetchone()
        conn.close()
        if not row:
            return {"ok": False, "error": "not found"}
        d = dict(row)
        # Ensure JSON field is parsed if it's a string
        if isinstance(d.get("data"), str):
            try:
                d["data"] = json.loads(d["data"])
            except Exception:
                pass
        return {"ok": True, "memory": d}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@mcp.tool()  # type: ignore
def health() -> Dict[str, Any]:
    return {"ok": True, "service": "Remembrancer MCP", "http": STREAMABLE_HTTP}

@mcp.tool()  # type: ignore
def list_peers() -> Dict[str, Any]:
    cfg = os.path.join(ROOT, "ops", "data", "federation.yaml")
    if not os.path.isfile(cfg):
        return {"ok": True, "peers": []}
    try:
        import yaml
        doc = yaml.safe_load(open(cfg, "r", encoding="utf-8")) or {}
        return {"ok": True, "peers": doc.get("peers", [])}
    except Exception as e:
        return {"ok": False, "error": str(e)}

if __name__ == "__main__":
    if not mcp:
        sys.stderr.write("MCP SDK missing. Install with: pip install mcp\n")
        sys.exit(2)
    # Stdio by default; HTTP if REMEMBRANCER_MCP_HTTP=1
    mcp.run()

