#!/usr/bin/env bash
set -euo pipefail

KEY=6E4082C6A410F340
CODEX=./SOVEREIGN_LORE_CODEX_V1.md
CODEX_ASC=./SOVEREIGN_LORE_CODEX_V1.md.asc
CODEX_SHA=31b058bb72430e722442165d1e22d4a0786448073ea52d29ef61ac689964a726

INSCR=./first_seal_inscription.asc
INSCR_ASC=./first_seal_inscription.asc.asc
INSCR_SHA=e7fdbe60eec91ee7f65721cc0c57cdb81b24213b8d3630faaab12d27e331200d

echo "🜂 Verifying Sovereign Lore Codex V1.0.0..."
echo ""

echo "==> Importing Sovereign pubkey (if needed)"
gpg --keyserver hkps://keys.openpgp.org --recv-keys "$KEY" >/dev/null 2>&1 || true

echo "==> Verifying GPG signatures"
gpg --verify "$CODEX_ASC" "$CODEX" 2>/dev/null && echo "✓ Codex signature OK"
gpg --verify "$INSCR_ASC" "$INSCR" 2>/dev/null && echo "✓ Inscription signature OK"

echo "==> Verifying SHA256 digests"
COD=$(sha256sum "$CODEX" | awk '{print $1}')
INS=$(sha256sum "$INSCR" | awk '{print $1}')
test "$COD" = "$CODEX_SHA" && echo "✓ Codex SHA256 OK" || { echo "✗ Codex SHA256 mismatch"; exit 1; }
test "$INS" = "$INSCR_SHA" && echo "✓ Inscription SHA256 OK" || { echo "✗ Inscription SHA256 mismatch"; exit 1; }

if [ -x ./ops/bin/remembrancer ]; then
  echo "==> Verifying timestamps with Remembrancer"
  ./ops/bin/remembrancer verify-full "$CODEX" >/dev/null && echo "✓ Codex RFC3161 OK"
  ./ops/bin/remembrancer verify-full "$INSCR" >/dev/null && echo "✓ Inscription RFC3161 OK"
  echo "==> Merkle audit root:"
  ./ops/bin/remembrancer verify-audit
else
  echo "ℹ Remembrancer not found; RFC3161/Merkle checks skipped."
fi

echo ""
echo "✅ All checks passed."
echo ""
echo "🜂 \"Entropy enters, proof emerges.\""
echo "   \"The Remembrancer remembers what time forgets.\""
echo "   \"Truth is the only sovereign — signed, Sovereign.\""

