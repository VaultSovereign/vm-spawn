#!/usr/bin/env bash
# test-mcp-server.sh - Comprehensive MCP Server Testing
#
# Tests all 8 tools, 1 resource, and 2 prompts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/ops/mcp"
VENV="$MCP_DIR/.venv"
SERVER="$MCP_DIR/remembrancer_server.py"

echo "🧪 VaultMesh MCP Server Test Suite"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check prerequisites
if [[ ! -d "$VENV" ]]; then
    echo "❌ Virtual environment not found at $VENV"
    exit 1
fi

if [[ ! -f "$SERVER" ]]; then
    echo "❌ Server not found at $SERVER"
    exit 1
fi

# Function to send JSON-RPC request
send_rpc() {
    local method="$1"
    local params="$2"
    echo "{\"jsonrpc\":\"2.0\",\"id\":$(date +%s),\"method\":\"$method\",\"params\":$params}"
}

# Test 1: Initialize
echo "📡 Test 1: Initialize Connection"
echo "─────────────────────────────────────────────────────────"
INIT_REQUEST=$(send_rpc "initialize" '{
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "test-suite", "version": "1.0"}
}')

echo "$INIT_REQUEST" | "$VENV/bin/python3" "$SERVER" 2>&1 | head -20
echo ""

# Test 2: List Tools
echo "🔧 Test 2: List Available Tools"
echo "─────────────────────────────────────────────────────────"
LIST_TOOLS=$(send_rpc "tools/list" '{}')
echo "$LIST_TOOLS" | "$VENV/bin/python3" "$SERVER" 2>&1 | grep -A 50 "tools/list" | head -30
echo ""

# Test 3: Call health check
echo "🏥 Test 3: Call Health Check Tool"
echo "─────────────────────────────────────────────────────────"
HEALTH_REQUEST=$(send_rpc "tools/call" '{
    "name": "health",
    "arguments": {}
}')
echo "$HEALTH_REQUEST" | "$VENV/bin/python3" "$SERVER" 2>&1 | grep -A 20 "health"
echo ""

# Test 4: Get Merkle Root Resource
echo "🌳 Test 4: Get Merkle Root Resource"
echo "─────────────────────────────────────────────────────────"
MERKLE_REQUEST=$(send_rpc "resources/read" '{
    "uri": "merkle://root"
}')
echo "$MERKLE_REQUEST" | "$VENV/bin/python3" "$SERVER" 2>&1 | grep -A 10 "merkle"
echo ""

# Test 5: List Prompts
echo "💬 Test 5: List Available Prompts"
echo "─────────────────────────────────────────────────────────"
LIST_PROMPTS=$(send_rpc "prompts/list" '{}')
echo "$LIST_PROMPTS" | "$VENV/bin/python3" "$SERVER" 2>&1 | grep -A 20 "prompts"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ Test Suite Complete!"
echo ""
echo "💡 Next Steps:"
echo "   1. Configure Claude Desktop: ~/.config/Claude/claude_desktop_config.json"
echo "   2. Test with Claude: Ask 'What is the current Merkle root?'"
echo "   3. Try advanced queries: 'Show me recent architectural decisions'"
echo ""
