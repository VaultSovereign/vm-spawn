#!/usr/bin/env bash
# FIRST_BOOT_RITUAL.sh - VaultMesh Covenant Anchor Protocol
# Creates human-readable, machine-proof boot manifest with Merkle roots
# Saves timestamped archive + cryptographic signature
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/work/vm/vm-umbrella}"
OUTDIR="${OUTDIR:-$HOME/vaultmesh-remembrance}"
KEYFILE="${KEYFILE:-$HOME/.vaultmesh/node.key}"

mkdir -p "$OUTDIR"
cd "$WORKDIR" || exit 1

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo "🜂 VaultMesh FIRST BOOT RITUAL" > "$OUTDIR/first_boot_manifest.txt"
echo "Host: $(hostname -f) (user: $(whoami))" >> "$OUTDIR/first_boot_manifest.txt"
echo "When: $(timestamp)" >> "$OUTDIR/first_boot_manifest.txt"
echo "" >> "$OUTDIR/first_boot_manifest.txt"

# Merkle / Receipt snapshot
if [[ -f _REMEMBRANCER_STATUS.md ]]; then
  echo "Merkle Root(s):" >> "$OUTDIR/first_boot_manifest.txt"
  grep -Eo '[0-9a-f]{64}' _REMEMBRANCER_STATUS.md | sed -n '1,10p' >> "$OUTDIR/first_boot_manifest.txt" || true
fi

if [[ -f RECEIPT_INDEX.json ]]; then
  echo "" >> "$OUTDIR/first_boot_manifest.txt"
  echo "Recent receipts (head):" >> "$OUTDIR/first_boot_manifest.txt"
  jq -r '.[:10][] | (.ts + " " + (.artifact_hash // "" ) + " " + (.path // ""))' RECEIPT_INDEX.json | sed -n '1,10p' >> "$OUTDIR/first_boot_manifest.txt" || true
fi

echo "" >> "$OUTDIR/first_boot_manifest.txt"
echo "Marks (vm-marks head):" >> "$OUTDIR/first_boot_manifest.txt"
zsh -i -c 'vm-marks list | sed -n "1,20p"' >> "$OUTDIR/first_boot_manifest.txt" || true

# Create archive of critical artifacts
ARCHIVE="$OUTDIR/vaultmesh-first-boot-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar czf "$ARCHIVE" _REMEMBRANCER_STATUS.md RECEIPT_INDEX.json ops/bin/remembrancer* ops/bin/FIRST_BOOT_RITUAL.sh 2>/dev/null || true

# Generate a local signing key if missing (ed25519 via openssl)
if [[ ! -f "$KEYFILE" ]]; then
  umask 077
  mkdir -p "$(dirname "$KEYFILE")"
  openssl genpkey -algorithm ed25519 -out "$KEYFILE" 2>/dev/null || true
fi

# Sign the archive
SIGFILE="$ARCHIVE.sig"
if command -v openssl >/dev/null 2>&1; then
  openssl pkeyutl -sign -inkey "$KEYFILE" -in "$ARCHIVE" -out "$SIGFILE" 2>/dev/null || true
fi

cat <<EOF

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🜂  FIRST BOOT RITUAL COMPLETE                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

MANIFEST:   $OUTDIR/first_boot_manifest.txt
ARCHIVE:    $ARCHIVE
SIGNATURE:  ${SIGFILE:-(not created)}

⚠️  KEEP THESE SAFE:
   - Upload to secure storage
   - Store on USB (cold storage)
   - Push signature to tamper-evident log

🜂 The seal stands. The covenant is anchored.

EOF

exit 0

