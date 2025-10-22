#!/usr/bin/env bash
# start-mcp-server.sh - Start the Remembrancer MCP Server
#
# Usage:
#   ./start-mcp-server.sh          # Start in stdio mode (for Claude Desktop)
#   ./start-mcp-server.sh --http   # Start in HTTP mode (for web agents)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/ops/mcp"
VENV="$MCP_DIR/.venv"

# Check if venv exists
if [[ ! -d "$VENV" ]]; then
    echo "❌ Virtual environment not found at $VENV"
    echo "Run setup first:"
    echo "  cd ops/mcp"
    echo "  uv venv .venv"
    echo "  uv pip install mcp fastmcp pyyaml"
    exit 1
fi

# Check mode
MODE="${1:-stdio}"
if [[ "$MODE" == "--http" ]]; then
    echo "🌐 Starting Remembrancer MCP Server in HTTP mode..."
    export REMEMBRANCER_MCP_HTTP=1
    exec "$VENV/bin/python3" "$MCP_DIR/remembrancer_server.py"
else
    echo "📡 Starting Remembrancer MCP Server in stdio mode..."
    echo "   (for Claude Desktop or MCP Inspector)"
    echo ""
    exec "$VENV/bin/python3" "$MCP_DIR/remembrancer_server.py"
fi
