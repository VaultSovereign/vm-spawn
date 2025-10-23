from __future__ import annotations
from typing import Any
from datetime import datetime
import os, json, logging

from mcp.server.fastmcp import FastMCP

# Configure logging to stderr (critical for stdio transport).
logging.basicConfig(level=logging.INFO)

SERVICE_NAME = "__SERVICE_NAME__"
STREAMABLE_HTTP = "__STREAMABLE_HTTP__" == "1"

# Initialize MCP server
mcp = FastMCP(SERVICE_NAME, streamable_http_path="/mcp" if STREAMABLE_HTTP else None)

# ----------------------------- Resources -------------------------------------
@mcp.resource("memory://{namespace}/{id}")
def memory(namespace: str, id: str) -> str:
    """Return a memory document by namespace/id as JSON."""
    doc = {
        "schema_version": "1.0",
        "id": f"mem:{namespace}/{id}",
        "namespace": namespace,
        "title": f"Memory {id}",
        "body": "…",
        "created_at": datetime.utcnow().isoformat() + "Z",
    }
    return json.dumps(doc, ensure_ascii=False)

@mcp.resource("adr://{year}/ADR-{num}")
def adr(year: int, num: int) -> str:
    """ADR text."""
    return f"""# ADR-{num} ({year})
Status: Proposed
Context: …
Decision: …
Consequences: …
"""

# ------------------------------- Tools ---------------------------------------
@mcp.tool()
def search_memories(query: str, limit: int = 20) -> list[dict[str, Any]]:
    """Semantic search across Remembrancer namespaces.
    Returns list of {'id','title','score'} maps."""
    return [{
        "id": "mem:covenant/abc123",
        "title": "Decision: Adopt MCP",
        "score": 0.91,
    }]

@mcp.tool()
def record_decision(title: str, body: str, tags: list[str] | None = None) -> dict[str, Any]:
    """Record a decision and return an ADR ref (skeleton)."""
    aid = "ADR-004"
    return {"adr": f"adr://2025/{aid}", "title": title, "tags": tags or []}

# ------------------------------ Prompts --------------------------------------
@mcp.prompt()
def decision_summary(title: str, context: str, decision: str, consequences: str) -> str:
    """LLM prompt template for summarizing a decision."""
    return f"""You are the Remembrancer for VaultMesh.
Summarize the ADR:

Title: {title}
Context: {context}
Decision: {decision}
Consequences: {consequences}

Output: executive summary + risk register.
"""