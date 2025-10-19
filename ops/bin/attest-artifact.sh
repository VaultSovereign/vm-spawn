#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMEMBRANCER="${WORKSPACE_ROOT}/ops/bin/remembrancer"

usage() {
  cat <<EOF
Usage: ops/bin/attest-artifact.sh <artifact> <gpg-key-id>

Creates full proof chain:
  1. Sign with GPG
  2. Timestamp with RFC3161
  3. Verify full chain
  4. Export proof bundle

Example:
  ops/bin/attest-artifact.sh dist/release.tar.gz my-key-id
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

ARTIFACT="$1"
KEY_ID="$2"

if [[ ! -f "$ARTIFACT" ]]; then
  echo "❌ Artifact not found: $ARTIFACT"
  exit 1
fi

echo "🔐 Attesting artifact: $ARTIFACT"
echo "   Key ID: $KEY_ID"
echo ""

# 1. Sign
echo "→ Step 1/4: Signing with GPG"
"$REMEMBRANCER" sign "$ARTIFACT" --key "$KEY_ID"

# 2. Timestamp
echo "→ Step 2/4: Timestamping with RFC3161"
"$REMEMBRANCER" timestamp "$ARTIFACT"

# 3. Verify
echo "→ Step 3/4: Verifying full chain"
"$REMEMBRANCER" verify-full "$ARTIFACT"

# 4. Export proof
echo "→ Step 4/4: Exporting proof bundle"
"$REMEMBRANCER" export-proof "$ARTIFACT"

echo ""
echo "✅ Attestation complete!"
echo "   Signature: ${ARTIFACT}.asc"
echo "   Timestamp: ${ARTIFACT}.tsr"
if [[ "$ARTIFACT" == *.tar.gz ]]; then
  echo "   Proof bundle: ${ARTIFACT%.tar.gz}.proof.tgz"
else
  echo "   Proof bundle: ${ARTIFACT}.proof.tgz"
fi

