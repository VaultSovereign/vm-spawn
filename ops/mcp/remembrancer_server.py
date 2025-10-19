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
except Exception as e:  # pragma: no cover
    sys.stderr.write("FastMCP not available. Install via: pip install mcp\n")
    raise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REM  = os.path.join(ROOT, "ops", "bin", "remembrancer")
DB   = os.path.join(ROOT, "ops", "data", "remembrancer.db")

# Optional HTTP transport (disabled by default; enable by env)
STREAMABLE_HTTP = os.getenv("REMEMBRANCER_MCP_HTTP", "").lower() in ("1", "true", "yes")
if STREAMABLE_HTTP:
    mcp = FastMCP("Remembrancer", streamable_http_path="/mcp")
else:
    mcp = FastMCP("Remembrancer")

def _run(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, check=False)

# ------------------------------ Resources ------------------------------------
@mcp.resource("memory://local/{memory_id}")
def memory_local(memory_id: str) -> str:
    # Minimal surface: delegate to CLI search or a direct DB query later
    # Here we return a JSON stub so the resource exists
    return json.dumps({"id": memory_id, "source": "local", "note": "MVP resource"})

@mcp.resource("adr://local/{year}/ADR-{num}")
def adr_local(year: int, num: int) -> str:
    # Delegate to CLI in future; return ADR skeleton for now
    return f"# ADR-{num:03d} ({year})\nStatus: Proposed\nContext: …\nDecision: …\nConsequences: …\n"

@mcp.resource("receipt://deploy/{component}/{version}")
def receipt_deploy(component: str, version: str) -> str:
    # In future: parse YAML receipt; MVP returns a stub
    return json.dumps({"component": component, "version": version, "receipt": "MVP stub"})

@mcp.resource("merkle://root")
def merkle_root() -> str:
    # Compute via merkle.py if present; otherwise placeholder
    merkle_py = os.path.join(ROOT, "ops", "lib", "merkle.py")
    if os.path.isfile(merkle_py) and os.path.isfile(DB):
        p = _run([sys.executable, merkle_py, "--compute", "--from-sqlite", DB])
        if p.returncode == 0:
            return p.stdout.strip()
    return ""

# -------------------------------- Tools --------------------------------------
@mcp.tool()
def search_memories(query: str, scope: str = "local", limit: int = 25) -> List[Dict[str, Any]]:
    """
    MVP: naive delegation not implemented; return a single stub match.
    Future: wire to CLI/SQLite FTS.
    """
    return [{"id": "mem:covenant/abc123", "title": f"Result for {query}", "score": 0.9}]

@mcp.tool()
def verify_artifact(artifact_path: str) -> Dict[str, Any]:
    """
    Call 'remembrancer verify-full' and parse a coarse result.
    """
    if not os.path.isfile(artifact_path):
        return {"ok": False, "error": f"Not found: {artifact_path}"}
    p = _run([REM, "verify-full", artifact_path])
    ok = (p.returncode == 0)
    return {"ok": ok, "stdout": p.stdout, "stderr": p.stderr}

@mcp.tool()
def sign_artifact(artifact_path: str, key_id: str) -> Dict[str, Any]:
    if not os.path.isfile(artifact_path):
        return {"ok": False, "error": f"Not found: {artifact_path}"}
    p = _run([REM, "sign", artifact_path, "--key", key_id])
    return {"ok": p.returncode == 0, "stdout": p.stdout, "stderr": p.stderr}

@mcp.tool()
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

@mcp.prompt()
def deployment_postmortem(component: str, version: str) -> str:
    return f"""Create a deployment postmortem.
Component: {component}
Version: {version}
Include timeline, impact, root cause, and improvements."""

if __name__ == "__main__":
    # Stdio by default; HTTP if REMEMBRANCER_MCP_HTTP=1
    mcp.run()

