# 🤖 AI Agent Integration - Quick Start Guide

**Status:** ✅ MCP Server Operational
**Date:** 2025-10-21
**For:** Claude Desktop, GPT-4, Custom LLM Agents

---

## 🎯 What You Can Do Now

With the MCP server running, AI agents can:

1. **Query Infrastructure History**
   - "What decisions did we make about Kubernetes?"
   - "Show me all deployments from last month"
   - "Why did we choose PostgreSQL?"

2. **Verify Cryptographic Proofs**
   - "Verify the integrity of genesis.tar.gz"
   - "Check if this artifact has a valid timestamp"
   - "Show me the current Merkle root"

3. **Record Decisions with Proofs**
   - "Record this architectural decision with a timestamp"
   - "Sign this release artifact"
   - "Create an ADR for migrating to GraphQL"

4. **Generate Documentation**
   - "Draft an ADR template for me"
   - "Generate a deployment postmortem"

---

## 🚀 30-Second Setup for Claude Desktop

### 1. Find Your Config File

**macOS:**
```bash
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

**Linux:**
```bash
nano ~/.config/Claude/claude_desktop_config.json
```

### 2. Add This Configuration

```json
{
  "mcpServers": {
    "remembrancer": {
      "command": "/home/sovereign/vm-spawn/ops/mcp/.venv/bin/python3",
      "args": [
        "/home/sovereign/vm-spawn/ops/mcp/remembrancer_server.py"
      ]
    }
  }
}
```

### 3. Restart Claude Desktop

That's it! Claude now has access to your infrastructure memory.

---

## 💬 Example Conversations

### Example 1: Query Infrastructure Decisions

**You:**
> "What architectural decisions have we made?"

**Claude (via MCP):**
> I'll search the Remembrancer for architectural decisions...
>
> *[Calls: search_memories(query="architectural decisions")]*
>
> Found 15 ADRs:
> - ADR-001: Why bash scripts (2024-03-15, GPG verified ✅)
> - ADR-002: Default monitoring (2024-04-20, GPG verified ✅)
> - ADR-007: GPG over X.509 (2024-10-15, GPG verified ✅)
> ...

### Example 2: Verify Artifact

**You:**
> "Is genesis.tar.gz cryptographically valid?"

**Claude (via MCP):**
> Let me verify the artifact...
>
> *[Calls: verify_artifact("dist/genesis.tar.gz")]*
>
> ✅ Verification Results:
> - SHA256: 44e8ecd... ✅
> - GPG Signature: Valid ✅
> - RFC3161 Timestamp: Valid ✅
> - Merkle Root: Verified ✅
>
> This artifact is cryptographically valid and hasn't been tampered with.

### Example 3: Generate ADR

**You:**
> "Help me create an ADR for adopting GraphQL"

**Claude (via MCP):**
> I'll generate an ADR template for you...
>
> *[Calls: adr_template("Adopt GraphQL", "REST APIs becoming unwieldy")]*
>
> Here's the draft:
>
> ```markdown
> # ADR-015: Adopt GraphQL
>
> Status: Proposed
> Date: 2025-10-21
>
> ## Context
> REST APIs becoming unwieldy with 50+ endpoints...
>
> ## Decision
> We will adopt GraphQL for our API layer...
>
> ## Consequences
> ...
> ```
>
> Would you like me to record this decision with a cryptographic signature?

### Example 4: Check System Health

**You:**
> "Is the Remembrancer system healthy?"

**Claude (via MCP):**
> Let me check the system status...
>
> *[Calls: health()]*
>
> ✅ Remembrancer MCP Server is healthy
> - Service: Running
> - Mode: stdio
> - Merkle Root: d5c64aee...decea
>
> Everything looks good!

---

## 🧪 Test It Manually First

Before integrating with Claude, test manually:

```bash
# 1. Start the server
./start-mcp-server.sh

# 2. In another terminal, send a test request
cat > /tmp/test.json << 'EOF'
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "health", "arguments": {}}}
EOF

cat /tmp/test.json | /home/sovereign/vm-spawn/ops/mcp/.venv/bin/python3 ops/mcp/remembrancer_server.py
```

Expected: JSON response with health status.

---

## 🛠️ Available MCP Tools

### 1. search_memories
**Purpose:** Query infrastructure history
**Parameters:**
- `query` (string) - Search query
- `scope` (string, optional) - "local" or "federated"
- `limit` (int, optional) - Max results (default: 25)

**Example:**
```python
search_memories(query="kubernetes decisions", limit=10)
```

### 2. verify_artifact
**Purpose:** Verify cryptographic proofs
**Parameters:**
- `artifact_path` (string) - Path to artifact

**Example:**
```python
verify_artifact(artifact_path="dist/genesis.tar.gz")
```

### 3. sign_artifact
**Purpose:** Sign artifact with GPG
**Parameters:**
- `artifact_path` (string) - Path to artifact
- `key_id` (string) - GPG key ID

**Example:**
```python
sign_artifact(artifact_path="release.tar.gz", key_id="6E4082C6A410F340")
```

### 4. record_decision
**Purpose:** Record architectural decision
**Parameters:**
- `title` (string) - Decision title
- `body` (string) - Decision content
- `tags` (list, optional) - Tags
- `sign` (bool, optional) - Sign with GPG

**Example:**
```python
record_decision(
    title="Adopt GraphQL",
    body="We're migrating to GraphQL because...",
    tags=["adr", "graphql"],
    sign=True
)
```

### 5. list_memory_ids
**Purpose:** List all memory IDs
**Parameters:**
- `limit` (int, optional) - Max results (default: 10000)

### 6. get_memory
**Purpose:** Fetch specific memory by ID
**Parameters:**
- `memory_id` (string) - Memory identifier

### 7. health
**Purpose:** Check server health
**Parameters:** None

### 8. list_peers
**Purpose:** List federation peers
**Parameters:** None

---

## 📦 Available Resources

### merkle://root
**Purpose:** Get current Merkle audit root
**Type:** text/plain
**Current Value:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

**Usage:** AI agents can read this to verify audit log integrity.

---

## 🎨 Available Prompts

### 1. adr_template
**Purpose:** Generate ADR skeleton
**Parameters:**
- `title` (string) - ADR title
- `context` (string) - Decision context

**Returns:** Formatted prompt for AI to draft ADR

### 2. deployment_postmortem
**Purpose:** Generate deployment postmortem
**Parameters:**
- `component` (string) - Component name
- `version` (string) - Version deployed

**Returns:** Formatted prompt for postmortem analysis

---

## 🔐 Security Model

### What AI Agents Can Access
- ✅ Read infrastructure history (query only)
- ✅ Verify existing signatures/timestamps
- ✅ Record NEW decisions (with your approval)
- ✅ Generate documentation from templates

### What AI Agents CANNOT Do
- ❌ Modify historical records (Merkle tree protects)
- ❌ Forge signatures (requires private key)
- ❌ Bypass timestamps (external TSA verification)
- ❌ Execute arbitrary code (sandboxed MCP tools)

### Trust Chain
```
You → Claude Desktop → MCP Server → Remembrancer CLI → SQLite + Merkle Tree
      (approval)    (JSON-RPC)    (subprocess)       (cryptographic)
```

---

## 🌟 Advanced: Federation Mode

To enable multi-node AI coordination:

```bash
# 1. Initialize federation
./ops/bin/remembrancer federation init

# 2. Start MCP in HTTP mode
./start-mcp-server.sh --http

# 3. AI agents can now query across multiple nodes
search_memories(query="...", scope="federated")
```

---

## 📊 Performance

- **Query latency:** ~50ms (SQLite FTS)
- **Verify artifact:** ~200ms (GPG + OpenSSL)
- **Merkle root:** ~10ms (cached)
- **Federation sync:** ~1s per peer

---

## 🐛 Troubleshooting

### "Cannot connect to MCP server"
- Check that `claude_desktop_config.json` has correct paths
- Verify: `ls /home/sovereign/vm-spawn/ops/mcp/.venv/bin/python3`
- Restart Claude Desktop

### "Tool execution failed"
- Check logs: `~/.config/Claude/logs/`
- Test manually: `./start-mcp-server.sh < /tmp/test.json`

### "GPG signing failed"
- Verify GPG key: `gpg --list-secret-keys`
- Set key ID: `export GPG_KEY_ID=<your-key>`

---

## 🎯 Next Steps

1. ✅ **You are here:** MCP server is running
2. **Configure Claude Desktop** (see setup above)
3. **Test with simple queries:**
   - "What is the current Merkle root?"
   - "List all available tools"
3. **Try advanced queries:**
   - "What decisions have we made about infrastructure?"
   - "Verify genesis.tar.gz"
4. **Record a decision:**
   - "Help me create an ADR for adopting Redis"
5. **Spawn services with MCP:**
   ```bash
   ./spawn.sh my-service service --with-mcp
   ```

---

## 📚 Documentation

- **Full Setup Guide:** [MCP_SETUP_COMPLETE.md](MCP_SETUP_COMPLETE.md)
- **MCP Server README:** [ops/mcp/README.md](ops/mcp/README.md)
- **Architecture Guide:** [AGENTS.md](AGENTS.md)
- **C3L Proposal:** [PROPOSAL_MCP_COMMUNICATION_LAYER.md](PROPOSAL_MCP_COMMUNICATION_LAYER.md)

---

**🜂 The agents are ready. The memory is sovereign. Begin the conversation.**

**Enjoy AI-powered infrastructure archaeology! 🚀**
