#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK_SRC="${SCRIPT_DIR}/.git/hooks/pre-commit"

mkdir -p "$(dirname "$HOOK_SRC")"

cat > "$HOOK_SRC" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

# Block committing real TSA certs by accident
if git diff --cached --name-only | grep -E '^ops/certs/.*\.pem$' | grep -v '\.example$' >/dev/null; then
  echo "❌ Refusing to commit TSA CA PEMs."
  echo "   Use freetsa-ca.pem.example + README.md for documentation."
  echo "   Real CAs should be deployed via ops tooling, not VCS."
  exit 1
fi

echo "✅ Pre-commit check passed"
HOOK

chmod +x "$HOOK_SRC"
echo "✅ Pre-commit hook installed at $HOOK_SRC"

