# FastMCP Installation — Complete

**Status:** ✅ INSTALLED & TESTED
**Commit:** `b772080`
**Branch:** `v4.0-kickoff` (pushed to GitHub)

---

## Installation Summary

### Environment
- **Python:** 3.13.7
- **Package Manager:** uv 0.8.19
- **Virtual Environment:** `ops/mcp/.venv`

### Dependencies Installed
```
✅ mcp SDK (core protocol)
✅ fastmcp (FastMCP server framework v1.18.0)
✅ pydantic v2.12.3 (settings + validation)
✅ uvicorn v0.38.0 (HTTP transport)
✅ starlette v0.48.0 (ASGI framework)
✅ rich v14.2.0 (terminal formatting)
+ 30 additional dependencies
```

---

## What Was Fixed

### Issue
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
streamable_http_path
  Input should be a valid string [type=string_type, input_value=None, input_type=NoneType]
```

### Root Cause
FastMCP `streamable_http_path` parameter doesn't accept `None` in recent versions.

### Solution
Conditional initialization:
```python
if STREAMABLE_HTTP:
    mcp = FastMCP("Remembrancer", streamable_http_path="/mcp")
else:
    mcp = FastMCP("Remembrancer")  # stdio only
```

---

## Verification Tests Passed

### 1. Installation ✅
```bash
source ops/mcp/.venv/bin/activate
python -c "from fastmcp import FastMCP; print('✅ FastMCP installed')"
# Output: ✅ FastMCP installed
```

### 2. Server Imports ✅
```bash
python -c "import sys; sys.path.insert(0, 'ops/mcp'); import remembrancer_server"
# Output: ✅ remembrancer_server.py imports successfully
```

### 3. MCP Protocol Handshake ✅
```json
Request:
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {...}}

Response:
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "experimental": {},
      "prompts": {"listChanged": false},
      "resources": {"subscribe": false, "listChanged": false},
      "tools": {"listChanged": false}
    },
    "serverInfo": {
      "name": "Remembrancer",
      "version": "1.18.0"
    }
  }
}
```

### 4. Tools Exposed ✅
```
search_memories     — Query memories by text/tags
verify_artifact     — Full chain verification (hash + GPG + timestamp)
sign_artifact       — GPG sign artifact
record_decision     — Record ADR with optional signature
```

### 5. Resources Exposed ✅
```
merkle://root — Current Merkle root from audit DB
```

### 6. Prompts Defined ✅
```
adr_template           — Generate ADR skeleton
deployment_postmortem  — Generate postmortem from receipts
```

---

## Quick Start

### Run Server (stdio)
```bash
source ops/mcp/.venv/bin/activate
python ops/mcp/remembrancer_server.py
# Server listens on stdin/stdout
```

### Test with MCP Inspector
```bash
cd ops/mcp
source .venv/bin/activate
mcp dev remembrancer_server.py
# Opens interactive MCP Inspector
```

### List Available Tools
```bash
cat > /tmp/test.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}
EOF

source ops/mcp/.venv/bin/activate
timeout 3s python ops/mcp/remembrancer_server.py < /tmp/test.json | jq 'select(.id==2) | .result.tools[] | .name'
```

Output:
```
search_memories
verify_artifact
sign_artifact
record_decision
```

---

## Files Created/Modified

| File | Status | Purpose |
|------|--------|---------|
| `ops/mcp/.venv/` | Created | Virtual environment (30+ packages) |
| `ops/mcp/remembrancer_server.py` | Fixed | Conditional FastMCP init |
| `ops/mcp/README.md` | Created | Complete installation + usage guide |
| `ops/mcp/.gitignore` | Created | Exclude .venv from VCS |
| `FASTMCP_INSTALLATION.md` | Created | This document |

---

## Integration Options

### 1. Claude Desktop
Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "remembrancer": {
      "command": "/usr/bin/env",
      "args": [
        "bash",
        "-c",
        "source /path/to/ops/mcp/.venv/bin/activate && python /path/to/ops/mcp/remembrancer_server.py"
      ]
    }
  }
}
```

### 2. HTTP Mode (Experimental)
```bash
REMEMBRANCER_MCP_HTTP=1 python ops/mcp/remembrancer_server.py
# Server listens on HTTP (port configured by FastMCP)
```

### 3. Direct CLI Wrapping
```python
from mcp.client.stdio import stdio_client

async with stdio_client("python", "ops/mcp/remembrancer_server.py") as client:
    tools = await client.list_tools()
    print(tools)
```

---

## Architecture

```
┌─────────────────────────────────────────┐
│  remembrancer_server.py (FastMCP)      │
├─────────────────────────────────────────┤
│  Resources:                             │
│    • merkle://root                      │
├─────────────────────────────────────────┤
│  Tools:                                 │
│    • search_memories                    │
│    • verify_artifact                    │
│    • sign_artifact                      │
│    • record_decision                    │
├─────────────────────────────────────────┤
│  Prompts:                               │
│    • adr_template                       │
│    • deployment_postmortem              │
└─────────────────────────────────────────┘
            ↓ subprocess calls
┌─────────────────────────────────────────┐
│  ops/bin/remembrancer (Bash CLI)       │
├─────────────────────────────────────────┤
│  • verify-full                          │
│  • sign                                 │
│  • timestamp                            │
│  • query                                │
│  • federation {init|join|status}        │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  ops/data/remembrancer.db (SQLite)     │
│  ops/lib/merkle.py                      │
│  ops/lib/federation.py                  │
└─────────────────────────────────────────┘
```

---

## Next Steps

### Week 3-4: Federation Sync Protocol
- [ ] Wire `search_memories` to SQLite FTS
- [ ] Implement `MerkleDiff.compute_diff()`
- [ ] Implement `MemoryValidator.verify_memory()`
- [ ] Add `list_peers` resource
- [ ] HTTP transport testing

### Integration Testing
- [ ] Test with Claude Desktop MCP integration
- [ ] Test multi-node federation sync
- [ ] Performance benchmarks (1k+ memories)

### Documentation
- [ ] Add MCP server to main README.md
- [ ] Create video demo (MCP Inspector)
- [ ] Update V4.0_KICKOFF.md progress

---

## Troubleshooting

### Virtual environment not active?
```bash
which python
# Should show: /path/to/ops/mcp/.venv/bin/python
```

### ImportError: No module named 'fastmcp'
```bash
source ops/mcp/.venv/bin/activate
uv pip install mcp fastmcp
```

### Server hangs on startup?
This is expected — MCP servers run as long-lived processes waiting for stdin.
Test with proper MCP protocol messages (see examples above).

---

## Success Metrics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| FastMCP installed | ✅ | v1.18.0 | ✅ |
| Server imports | ✅ | No errors | ✅ |
| MCP handshake | ✅ | Protocol 2024-11-05 | ✅ |
| Tools exposed | 4 | 4 | ✅ |
| Resources exposed | 1 | 1 | ✅ |
| Prompts defined | 2 | 2 | ✅ |
| Documentation | Complete | ops/mcp/README.md | ✅ |
| Commits pushed | ✅ | b772080 | ✅ |

---

🜂 **Solve et Coagula.**

**The MCP server breathes. The federation listens. The covenant holds.**

Installation complete. Ready for Week 3: Federation Sync Protocol.
