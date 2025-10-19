#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="${WORKSPACE_ROOT}/ops/data/remembrancer.db"
DOC="${WORKSPACE_ROOT}/docs/REMEMBRANCER.md"

if [[ ! -f "$DB" ]]; then
  echo "❌ No remembrancer.db found at $DB"
  exit 1
fi

echo "→ Computing Merkle root from $DB"
root=$(python3 "${WORKSPACE_ROOT}/ops/lib/merkle.py" --compute --from-sqlite "$DB")

echo "→ Current Merkle root: $root"

# Update or append to REMEMBRANCER.md
if grep -q "^Merkle Root:" "$DOC"; then
  # Update existing root
  sed -i.bak "s/^Merkle Root: .*/Merkle Root: $root/" "$DOC"
  rm -f "${DOC}.bak"
  echo "✅ Updated Merkle root in $DOC"
else
  # Append new root
  echo "" >> "$DOC"
  echo "Merkle Root: $root" >> "$DOC"
  echo "✅ Appended Merkle root to $DOC"
fi

echo ""
echo "Next steps:"
echo "  git add docs/REMEMBRANCER.md"
echo "  git commit -m 'chore: publish Merkle root $root'"

