#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
mcp-server.sh — scaffold an MCP server for a VaultMesh service.

Usage:
  generators/mcp-server.sh <service-name> [--dir <dest>] [--http] [--stdio]

Options:
  --dir     Destination directory (default: services/<service-name>)
  --http    Configure Streamable HTTP entrypoint (default is stdio-ready)
  --stdio   No-op; stdio is supported by default via `mcp dev`

This copies templates/mcp/server-template.py and replaces placeholders:
  __SERVICE_NAME__

It also creates a minimal pyproject.toml with mcp[cli] dependency if missing.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage; exit 0
fi

SERVICE="$1"; shift || true
DEST="services/${SERVICE}"
HTTP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DEST="$2"; shift 2;;
    --http) HTTP=1; shift;;
    --stdio) shift;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

mkdir -p "${DEST}/mcp"
SRC="templates/mcp/server-template.py"
DST="${DEST}/mcp/server.py"

if [[ ! -f "${SRC}" ]]; then
  echo "Template not found: ${SRC}" >&2; exit 1
fi

sed   -e "s/__SERVICE_NAME__/${SERVICE}/g"   -e "s/__STREAMABLE_HTTP__/$( [[ $HTTP -eq 1 ]] && echo '1' || echo '0' )/g"   "${SRC}" > "${DST}"

chmod +x "${DST}"

# Create minimal pyproject.toml if it doesn't exist
if [[ ! -f "${DEST}/pyproject.toml" ]]; then
  cat > "${DEST}/pyproject.toml" <<'PYPROJECT'
[project]
name = "vaultmesh-__SERVICE_NAME__"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = ["mcp[cli]>=1.2.0"]

[tool.mcp]
# Optional: installable entry using `uv run mcp dev mcp/server.py`
PYPROJECT
  sed -i.bak "s/__SERVICE_NAME__/${SERVICE}/g" "${DEST}/pyproject.toml" || true
fi

cat <<EOF
✅ MCP server scaffolded for '${SERVICE}' at ${DST}

Run locally with MCP Inspector (stdio):
  cd ${DEST}
  uv run mcp dev mcp/server.py

To install into a host (e.g., Claude Desktop):
  uv run mcp install mcp/server.py
EOF