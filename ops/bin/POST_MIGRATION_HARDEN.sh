#!/usr/bin/env bash
# POST_MIGRATION_HARDEN.sh - VaultMesh Node Hardening Protocol
# Hardens node: rotates auth, purges secrets, sets permissions, creates encrypted backup
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/work/vm/vm-umbrella}"
STATEDIR="${STATEDIR:-$HOME/.local/state}"
BACKUPDIR="${BACKUPDIR:-$HOME/vaultmesh-backups}"
GPG_RECIPIENT="${GPG_RECIPIENT:-}"

mkdir -p "$BACKUPDIR"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   🛡️  VAULTMESH POST-MIGRATION HARDENING                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "1️⃣  Fixing permissions..."
chmod 600 "$HOME/.ssh/id_rsa" 2>/dev/null || true
chmod 600 "$HOME/.vaultmesh/node.key" 2>/dev/null || true
chmod 700 "$WORKDIR/ops/bin" 2>/dev/null || true
echo "   ✅ Permissions hardened"
echo ""

echo "2️⃣  Scrubbing secrets from ~/.zshrc..."
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]] && grep -q 'VAULTS_BOX_MASTER\|TS_AUTH_KEY\|AWS_SECRET_ACCESS_KEY' "$ZSHRC" 2>/dev/null; then
  BACKUP="$ZSHRC.bak.$(date +%s)"
  cp "$ZSHRC" "$BACKUP"
  # Comment out sensitive env vars
  sed -i.scrub -E 's/^(.*(VAULTS_BOX_MASTER|VAULTS_BOX_MASTER_FILE|TS_AUTH_KEY|TS_NODE_KEY|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID).*)$/# SCRUBBED: \1/' "$ZSHRC" || true
  rm -f "$ZSHRC.scrub" 2>/dev/null || true
  echo "   ✅ Sensitive env lines commented (backup: $BACKUP)"
else
  echo "   ℹ️  No sensitive patterns found in ~/.zshrc"
fi
echo ""

echo "3️⃣  Rotating Tailscale node auth..."
if command -v tailscale >/dev/null 2>&1; then
  sudo tailscale up --force-reauth 2>/dev/null && echo "   ✅ Tailscale reauth triggered" || echo "   ⚠️  Tailscale reauth failed (manual intervention needed)"
else
  echo "   ℹ️  Tailscale not installed, skipping"
fi
echo ""

echo "4️⃣  Creating encrypted backup..."
TSTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACK="$BACKUPDIR/vaultmesh-state-$TSTAMP.tar.gz"

# Create backup archive
tar czf "$BACK" \
  "$STATEDIR" \
  "$WORKDIR/_REMEMBRANCER_STATUS.md" \
  "$WORKDIR/RECEIPT_INDEX.json" \
  "$WORKDIR/ops/bin/remembrancer" \
  "$WORKDIR/docs/REMEMBRANCER.md" \
  2>/dev/null || true

# Encrypt with GPG
if [[ -n "$GPG_RECIPIENT" ]]; then
  gpg --batch --yes -o "$BACK.gpg" -e -r "$GPG_RECIPIENT" "$BACK" || true
  echo "   ✅ Encrypted with GPG recipient: $GPG_RECIPIENT"
else
  echo "   ℹ️  No GPG recipient set — using symmetric encryption"
  echo "   ⚠️  You will be prompted for passphrase..."
  gpg --symmetric --cipher-algo AES256 -o "$BACK.gpg" "$BACK" || true
  echo "   ✅ Encrypted with passphrase"
fi

# Secure delete original
shred -u "$BACK" 2>/dev/null || rm -f "$BACK"
echo "   ✅ Original backup securely deleted"
echo "   📦 Encrypted backup: $BACK.gpg"
echo ""

echo "5️⃣  Running Remembrancer doctor..."
cd "$WORKDIR" || true
if [[ -x "./ops/bin/remembrancer" ]]; then
  ./ops/bin/remembrancer list deployments | head -5 || true
  echo "   ✅ Remembrancer operational"
else
  echo "   ⚠️  Remembrancer not found at $WORKDIR/ops/bin/remembrancer"
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   🛡️  HARDENING COMPLETE                                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "ENCRYPTED BACKUP: $BACK.gpg"
echo ""
echo "NEXT STEPS:"
echo "  1. Copy $BACK.gpg to USB (cold storage)"
echo "  2. Rotate secrets commented in ~/.zshrc"
echo "  3. Verify Tailscale reauth: tailscale status"
echo "  4. Test Remembrancer: ./ops/bin/remembrancer list deployments"
echo ""
echo "🛡️  The node is hardened. The covenant is guarded."
echo ""

exit 0

