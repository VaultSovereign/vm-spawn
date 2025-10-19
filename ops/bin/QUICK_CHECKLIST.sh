#!/usr/bin/env bash
# QUICK_CHECKLIST.sh - VaultMesh Covenant Verification
# Quick checklist to confirm state and capture initial proof
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/work/vm/vm-umbrella}"
cd "$WORKDIR" 2>/dev/null || cd "$(dirname "$0")/../.." || exit 1

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   ✅  VAULTMESH QUICK CHECKLIST                               ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Verify Remembrancer
echo "1️⃣  Remembrancer Status..."
if [[ -x "./ops/bin/remembrancer" ]]; then
  ./ops/bin/remembrancer list deployments 2>/dev/null | head -5 && echo "   ✅ Remembrancer operational" || echo "   ⚠️  Remembrancer has issues"
else
  echo "   ❌ Remembrancer not found or not executable"
fi
echo ""

# 2. Show latest receipts and Merkle root
echo "2️⃣  Merkle Roots + Receipts..."
if [[ -f "_REMEMBRANCER_STATUS.md" ]] || [[ -f "🧠_REMEMBRANCER_STATUS.md" ]]; then
  STATUSFILE=$(ls -1 *REMEMBRANCER_STATUS.md 2>/dev/null | head -1)
  echo "   Found status: $STATUSFILE"
  MERKLE=$(grep -Eo '[0-9a-f]{64}' "$STATUSFILE" 2>/dev/null | head -1 || echo "")
  if [[ -n "$MERKLE" ]]; then
    echo "   ✅ Merkle root: $MERKLE"
  else
    echo "   ⚠️  No merkle root found"
  fi
else
  echo "   ⚠️  REMEMBRANCER_STATUS.md not found"
fi

if [[ -f "RECEIPT_INDEX.json" ]]; then
  echo "   Recent receipts:"
  jq -r '.[] | .artifact_hash' RECEIPT_INDEX.json 2>/dev/null | head -3 | sed 's/^/     /' || echo "     (unable to parse)"
  echo "   ✅ Receipt index exists"
else
  echo "   ⚠️  RECEIPT_INDEX.json not found"
fi
echo ""

# 3. Verify spawn tar integrity
echo "3️⃣  Artifact Integrity..."
if [[ -f "vaultmesh-spawn-elite-v2.2-PRODUCTION.tar.gz" ]]; then
  COMPUTED=$(shasum -a 256 vaultmesh-spawn-elite-v2.2-PRODUCTION.tar.gz | awk '{print $1}')
  EXPECTED="44e8ecdcd17ac9e3695280c71f7507051c1fa17373593dc96e5c49b80b5c8dfd"
  if [[ "$COMPUTED" == "$EXPECTED" ]]; then
    echo "   ✅ v2.2-PRODUCTION artifact verified"
    echo "      SHA256: $COMPUTED"
  else
    echo "   ❌ Hash mismatch!"
    echo "      Expected: $EXPECTED"
    echo "      Got:      $COMPUTED"
  fi
else
  echo "   ⚠️  v2.2-PRODUCTION.tar.gz not found"
fi
echo ""

# 4. Confirm vm-marks OK
echo "4️⃣  VM Marks Status..."
if command -v zsh >/dev/null 2>&1; then
  MARKS=$(zsh -i -c 'vm-marks list 2>/dev/null | head -3' 2>/dev/null || echo "")
  if [[ -n "$MARKS" ]]; then
    echo "$MARKS" | sed 's/^/   /'
    echo "   ✅ vm-marks operational"
  else
    echo "   ⚠️  vm-marks not configured or empty"
  fi
else
  echo "   ⚠️  zsh not available"
fi
echo ""

# 5. System info
echo "5️⃣  System Info..."
echo "   Host: $(hostname -f 2>/dev/null || hostname)"
echo "   User: $(whoami)"
echo "   OS: $(uname -s) $(uname -r)"
echo "   Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Final verdict
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   ✅  CHECKLIST COMPLETE                                      ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "If all shows OK and SHA256 exists → the seal stands."
echo ""
echo "NEXT:"
echo "  ./ops/bin/FIRST_BOOT_RITUAL.sh      (anchor + archive)"
echo "  ./ops/bin/POST_MIGRATION_HARDEN.sh  (harden + encrypt)"
echo ""

exit 0

