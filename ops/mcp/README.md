# Remembrancer MCP Server

**Status:** ✅ v4.0 Foundation Complete
**Transport:** stdio (default) + HTTP (experimental)

---

## Installation

### 1. Install FastMCP SDK

```bash
# Create virtual environment
uv venv ops/mcp/.venv

# Activate and install
source ops/mcp/.venv/bin/activate
uv pip install mcp fastmcp

# Verify
python -c "from fastmcp import FastMCP; print('✅ FastMCP installed')"
```

### 2. Test Server

```bash
# Test syntax
python -m py_compile ops/mcp/remembrancer_server.py

# Test imports
python -c "import sys; sys.path.insert(0, 'ops/mcp'); import remembrancer_server; print('✅ Server imports successfully')"

# Test MCP protocol
cat > /tmp/test_init.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
EOF

source ops/mcp/.venv/bin/activate
timeout 3s python ops/mcp/remembrancer_server.py < /tmp/test_init.json
```

---

## Available MCP Endpoints

### Resources

- `merkle://root` — Current Merkle root from DB

### Tools (4)

1. **search_memories**
   - Query: `query` (string)
   - Scope: `local` (default)
   - Limit: 25 (default)
   - Returns: List of matching memories

2. **verify_artifact**
   - Artifact path: `artifact_path` (string)
   - Returns: {sha256, gpg_valid, timestamp_valid, overall_status}

3. **sign_artifact**
   - Artifact path: `artifact_path` (string)
   - Key ID: `key_id` (string)
   - Returns: Signature result

4. **record_decision**
   - Title: `title` (string)
   - Body: `body` (string)
   - Tags: `tags` (optional list)
   - Sign: `sign` (boolean, default false)
   - Returns: Decision ID + receipt

### Prompts (2)

1. **adr_template** — Generate ADR skeleton
2. **deployment_postmortem** — Generate postmortem from receipts

---

## Usage Modes

### stdio Mode (Default)

```bash
source ops/mcp/.venv/bin/activate
python ops/mcp/remembrancer_server.py
# Server listens on stdin/stdout for JSON-RPC messages
```

### HTTP Mode (Experimental)

```bash
source ops/mcp/.venv/bin/activate
REMEMBRANCER_MCP_HTTP=1 python ops/mcp/remembrancer_server.py
# Server listens on HTTP (port configured by FastMCP)
```

---

## Testing with MCP Inspector

```bash
# Install uv if not available
curl -LsSf https://astral.sh/uv/install.sh | sh

# Launch inspector (stdio mode)
cd ops/mcp
source .venv/bin/activate
mcp dev remembrancer_server.py
```

---

## Integration with Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "remembrancer": {
      "command": "/usr/bin/env",
      "args": [
        "bash",
        "-c",
        "source /path/to/vaultmesh/ops/mcp/.venv/bin/activate && python /path/to/vaultmesh/ops/mcp/remembrancer_server.py"
      ]
    }
  }
}
```

---

## Testing Commands

### List Tools
```bash
cat > /tmp/tools.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}
EOF

source ops/mcp/.venv/bin/activate
timeout 3s python ops/mcp/remembrancer_server.py < /tmp/tools.json | jq 'select(.id==2) | .result.tools[] | .name'
```

### List Resources
```bash
cat > /tmp/resources.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "resources/list"}
EOF

source ops/mcp/.venv/bin/activate
timeout 3s python ops/mcp/remembrancer_server.py < /tmp/resources.json | jq 'select(.id==2) | .result.resources[] | .uri'
```

### Call verify_artifact Tool
```bash
cat > /tmp/verify.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "verify_artifact", "arguments": {"artifact_path": "ops/test-artifacts/test-app.tar.gz"}}}
EOF

source ops/mcp/.venv/bin/activate
timeout 3s python ops/mcp/remembrancer_server.py < /tmp/verify.json | jq 'select(.id==2)'
```

---

## Troubleshooting

### "streamable_http_path validation error"
**Fixed in commit 15e772e+**
Conditional initialization based on `REMEMBRANCER_MCP_HTTP` env var.

### "FastMCP not available"
```bash
source ops/mcp/.venv/bin/activate
uv pip install mcp fastmcp
```

### "ModuleNotFoundError: No module named 'fastmcp'"
Make sure you're using the virtual environment:
```bash
source ops/mcp/.venv/bin/activate
which python  # Should show .venv/bin/python
```

---

## Architecture

```
remembrancer_server.py (115 lines)
├── Resources: merkle://root
├── Tools: search, verify, sign, record
├── Prompts: adr_template, deployment_postmortem
└── CLI Wrapper: subprocess calls to ops/bin/remembrancer
```

**Key Design:**
- Thin wrapper around existing CLI (zero duplication)
- AsyncIO-ready (all tools are async)
- Transport-agnostic (stdio default, HTTP opt-in)
- Federation-ready (scope parameter for multi-node queries)

---

## Next Steps (Weeks 3-4)

- [ ] Wire `search_memories` to SQLite FTS
- [ ] Add `get_receipt` tool
- [ ] Add `list_peers` resource (federation)
- [ ] HTTP transport testing
- [ ] Add prompts/get endpoint for ADR templates

---

🜂 **The federation breathes. The MCP server listens.**
