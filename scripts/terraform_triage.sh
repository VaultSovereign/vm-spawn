#!/usr/bin/env bash
##
## Terraform Triage — Identify canonical version among 3 divergent configs
##
set -euo pipefail

echo "🜂 Terraform Configuration Triage"
echo "   Analyzing 3 versions of gcp-confidential-vm terraform..."
echo

A="docs/gcp/confidential/gcp-confidential-vm.tf"
B="archive/gcp-confidential/gcp-confidential-vm.tf"
C="infrastructure/terraform/gcp/confidential-vm/main.tf"
CANONICAL="infrastructure/gcp/terraform/confidential-vm.tf"

# Check existence
for f in "$A" "$B" "$C"; do
  if [[ ! -f "$f" ]]; then
    echo "⚠️  File not found: $f"
  else
    lines=$(wc -l < "$f")
    size=$(du -h "$f" | cut -f1)
    hash=$(sha256sum "$f" | cut -d' ' -f1 | cut -c1-12)
    echo "✓ $f"
    echo "  Lines: $lines | Size: $size | Hash: $hash..."
  fi
done

echo
echo "=========================================="
echo "Diff: A (docs) vs C (infrastructure)"
echo "=========================================="
diff -u "$A" "$C" 2>/dev/null || echo "(Files differ or missing)"

echo
echo "=========================================="
echo "Diff: B (archive) vs C (infrastructure)"
echo "=========================================="
diff -u "$B" "$C" 2>/dev/null || echo "(Files differ or missing)"

echo
echo "=========================================="
echo "Diff: A (docs) vs B (archive)"
echo "=========================================="
diff -u "$A" "$B" 2>/dev/null || echo "(Files differ or missing)"

echo
echo "=========================================="
echo "RECOMMENDATION"
echo "=========================================="
echo
echo "1. **Review diffs above** to identify which version is current/production."
echo
echo "2. **Establish canonical source:**"
echo "   → Copy chosen version to: $CANONICAL"
echo
echo "3. **Archive old versions:**"
echo "   → Move docs/gcp/ and archive/gcp-confidential/ to archive/ with README explaining divergence"
echo
echo "4. **Document in infrastructure/gcp/terraform/README.md:**"
echo "   - Which version was chosen and why"
echo "   - Migration date: $(date -I)"
echo "   - Note about archived versions"
echo
echo "5. **Update terraform references** in deployment docs to point to canonical path"
echo
echo "Example commands:"
echo
echo "  # After determining correct version (e.g., C):"
echo "  cp \"$C\" \"$CANONICAL\""
echo "  git add \"$CANONICAL\""
echo "  git mv docs/gcp archive/gcp-docs-legacy-2025-10-23"
echo "  git commit -m 'chore(iac): canonicalize GCP terraform config'"
echo
echo "Astra inclinant, sed non obligant. 🜂"
