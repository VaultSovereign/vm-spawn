#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="$ROOT/ops/data/remembrancer.db"
FED_CFG="$ROOT/ops/data/federation.yaml"
CA="${FREETSA_CA:-$ROOT/ops/certs/freetsa-ca.pem}"

warn() { echo "⚠️  $*"; }
ok()   { echo "✅ $*"; }
fail=0

echo "=== VaultMesh Security Self-Check ==="

# 1) DB permissions
if [[ -f "$DB" ]]; then
  perm=$(stat -c '%a' "$DB" 2>/dev/null || stat -f '%Lp' "$DB" 2>/dev/null || echo "???")
  echo "DB: $DB (perm: $perm)"
  case "$perm" in
    600|640|660) ok "SQLite permissions acceptable";;
    *) warn "SQLite permissions should be 600 (current $perm)";;
  esac
else
  warn "No SQLite DB found at $DB (ok on fresh systems)"
fi

# 2) MCP HTTP exposure hint
if [[ "${REMEMBRANCER_MCP_HTTP:-}" =~ ^(1|true|yes)$ ]]; then
  warn "REMEMBRANCER_MCP_HTTP is enabled. Ensure reverse-proxy auth or mTLS protects /mcp."
else
  ok "MCP HTTP disabled (stdio mode)"
fi

# 3) TSA CA presence
if [[ -f "$CA" ]]; then
  ok "TSA CA present: $CA"
else
  warn "No TSA CA at $CA (timestamps will be unverifiable; GPG-only proofs)"
fi

# 4) Tooling presence
command -v gpg >/dev/null 2>&1 && ok "gpg present" || warn "gpg missing"
command -v openssl >/dev/null 2>&1 && ok "openssl present" || warn "openssl missing"
command -v sqlite3 >/dev/null 2>&1 && ok "sqlite3 present" || warn "sqlite3 missing"

# 5) Federation strict-mode toggle
if [[ -f "$FED_CFG" ]] && grep -q 'require_signatures:' "$FED_CFG"; then
  v=$(grep -m1 'require_signatures:' "$FED_CFG" | awk '{print $2}')
  echo "require_signatures: $v"
  [[ "$v" == "true" ]] && ok "Strict mode enabled" || warn "Strict mode disabled (permissive ingest)"
else
  warn "No federation.yaml or require_signatures not set (permissive ingest)"
fi

echo "=== Self-Check complete ==="
exit $fail

