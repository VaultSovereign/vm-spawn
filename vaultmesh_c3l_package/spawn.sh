#!/usr/bin/env bash
set -euo pipefail

# spawn.sh — extended with C3L flags

WITH_MCP=0
WITH_MQ=0
SERVICE=""
DEST="services"

usage() {
  cat <<'USAGE'
spawn.sh — spawn a VaultMesh service (extended for C3L)

Usage:
  ./spawn.sh <service-name> [--with-mcp] [--with-mq rabbitmq|nats]

Examples:
  ./spawn.sh herald --with-mcp --with-mq rabbitmq

Flags:
  --with-mcp           Scaffold an MCP server skeleton
  --with-mq <kind>     Add MQ client skeleton (rabbitmq or nats)
USAGE
}

if [[ $# -lt 1 ]]; then usage; exit 1; fi

SERVICE="$1"; shift || true

MQ_KIND="rabbitmq"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-mcp) WITH_MCP=1; shift;;
    --with-mq) WITH_MQ=1; MQ_KIND="${2:-rabbitmq}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

mkdir -p "${DEST}/${SERVICE}"

echo "🛠  Spawning service '${SERVICE}' into ${DEST}/${SERVICE}"

if [[ $WITH_MCP -eq 1 ]]; then
  bash generators/mcp-server.sh "${SERVICE}" --dir "${DEST}/${SERVICE}" >/dev/null
fi

if [[ $WITH_MQ -eq 1 ]]; then
  bash generators/message-queue.sh "${SERVICE}" --dir "${DEST}/${SERVICE}" --type "${MQ_KIND}" >/dev/null
fi

echo "✅ Done. Hints:"
if [[ $WITH_MCP -eq 1 ]]; then
  echo "   - MCP dev: cd ${DEST}/${SERVICE} && uv run mcp dev mcp/server.py"
fi
if [[ $WITH_MQ -eq 1 ]]; then
  echo "   - MQ worker: uv run python mq/mq.py"
fi