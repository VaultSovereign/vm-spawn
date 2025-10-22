#!/usr/bin/env bash
# slo-signer.sh - Signed SLO/governance kit
# Generates SLO report, signs with GPG, timestamps with RFC3161, and logs to ledger

set -euo pipefail

PROMETHEUS_URL="${1:-http://localhost:9090}"
OUTPUT_FILE="${2:-reports/slo-$(date +%Y%m%d).json}"
GPG_KEY="${GPG_KEY:-6E4082C6A410F340}"

echo "🜂 SLO Signer — Governance Report Generator"
echo "==========================================="
echo ""
echo "Prometheus: $PROMETHEUS_URL"
echo "Output: $OUTPUT_FILE"
echo "GPG Key: $GPG_KEY"
echo ""

# Generate SLO report
echo "1/4 Generating SLO report..."
python3 scripts/canary-slo-reporter.py \
  --prometheus "$PROMETHEUS_URL" \
  --output "$OUTPUT_FILE" \
  --key "$GPG_KEY" \
  --no-sign

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "❌ Failed to generate SLO report"
  exit 1
fi

# Sign with GPG
echo "2/4 Signing with GPG..."
gpg --detach-sign --armor --local-user "$GPG_KEY" "$OUTPUT_FILE"

if [[ ! -f "${OUTPUT_FILE}.asc" ]]; then
  echo "❌ Failed to sign report"
  exit 1
fi

# Timestamp with RFC3161
echo "3/4 Timestamping with RFC3161..."
if command -v openssl &>/dev/null; then
  if ./ops/bin/remembrancer timestamp "$OUTPUT_FILE" 2>/dev/null; then
    echo "  ✅ RFC3161 timestamp created"
  else
    echo "  ⚠️  RFC3161 timestamp skipped (TSA unavailable)"
  fi
else
  echo "  ⚠️  OpenSSL not available, skipping timestamp"
fi

# Log to ledger
echo "4/4 Logging to ledger..."
SHA256=$(shasum -a 256 "$OUTPUT_FILE" | awk '{print $1}')
echo "  SHA256: $SHA256"

# Record in Remembrancer
if [[ -x ops/bin/remembrancer ]]; then
  ops/bin/remembrancer record deploy \
    --component "aurora-slo-report" \
    --version "$(date +%Y%m%d)" \
    --sha256 "$SHA256" \
    --evidence "$OUTPUT_FILE" 2>/dev/null || true
fi

echo ""
echo "✅ SLO report complete:"
echo "   Report: $OUTPUT_FILE"
echo "   Signature: ${OUTPUT_FILE}.asc"
echo "   SHA256: $SHA256"
echo ""
echo "Verify with:"
echo "   gpg --verify ${OUTPUT_FILE}.asc $OUTPUT_FILE"
echo ""
echo "🜂 Governance artifact ready for docket"
