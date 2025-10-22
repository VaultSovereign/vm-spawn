#!/usr/bin/env bash
# treaty-generate.sh - Generate provider treaty from template
set -euo pipefail

PROVIDER_ID="${PROVIDER_ID:-}"
PROVIDER_NAME="${PROVIDER_NAME:-}"
ENDPOINT="${ENDPOINT:-}"

if [[ -z "$PROVIDER_ID" || -z "$PROVIDER_NAME" || -z "$ENDPOINT" ]]; then
  echo "Usage: PROVIDER_ID=<id> PROVIDER_NAME=\"<name>\" ENDPOINT=\"<url>\" $0"
  echo ""
  echo "Example:"
  echo "  PROVIDER_ID=akash PROVIDER_NAME=\"Akash Network\" ENDPOINT=\"https://api.akash.network\" $0"
  exit 1
fi

TEMPLATE="treaties/templates/aurora-treaty-template.yaml"
OUTPUT="treaties/aurora-${PROVIDER_ID}.yaml"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: Template not found: $TEMPLATE"
  exit 1
fi

# Generate treaty
envsubst < "$TEMPLATE" > "$OUTPUT"

echo "✅ Treaty generated: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. Review: cat $OUTPUT"
echo "  2. Deploy: kubectl apply -f $OUTPUT"
echo "  3. Verify: kubectl get treaty aurora-${PROVIDER_ID}"
