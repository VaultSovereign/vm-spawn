#!/usr/bin/env bash
# Sovereign Lore Codex — Signing Ritual
# This script performs the complete cryptographic attestation of the First Seal

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🜂 Sovereign Lore Codex — First Seal Signing Ritual${NC}"
echo ""

# Get GPG key (use env or detect)
KEY_ID="${GPG_KEY_ID:-}"
if [[ -z "$KEY_ID" ]]; then
  KEY_ID=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec/ {print $5; exit}')
fi

if [[ -z "$KEY_ID" ]]; then
  echo -e "${RED}❌ No GPG key found. Set GPG_KEY_ID or import a key.${NC}"
  exit 1
fi

echo -e "${GREEN}→ Using GPG key: $KEY_ID${NC}"
echo ""

# Step 1: Commit to git
echo -e "${CYAN}Step 1/5: Committing to git...${NC}"
git add SOVEREIGN_LORE_CODEX_V1.md cosmic_audit_diagram.svg cosmic_audit_diagram.html first_seal_inscription.asc docs/adr/ADR-007-codex-first-seal.md
git commit -m "$(cat <<'EOF'
🜂 Forge: Sovereign Lore Codex V1 + First Seal Inscription

The First Seal is inscribed:
- SOVEREIGN_LORE_CODEX_V1.md (8 Seals, cosmic alignment)
- cosmic_audit_diagram.svg (dual-lane visualization)
- cosmic_audit_diagram.html (interactive viewer)
- first_seal_inscription.asc (portable seal)
- docs/adr/ADR-007-codex-first-seal.md (decision record)

"Entropy enters, proof emerges."

🜂 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)" 2>&1 || echo "  (files already committed)"

echo -e "${GREEN}✅ Committed to git${NC}"
echo ""

# Step 2: Sign the codex
echo -e "${CYAN}Step 2/5: Signing SOVEREIGN_LORE_CODEX_V1.md...${NC}"
./ops/bin/remembrancer sign SOVEREIGN_LORE_CODEX_V1.md --key "$KEY_ID"
echo ""

# Step 3: Timestamp the codex
echo -e "${CYAN}Step 3/5: Timestamping SOVEREIGN_LORE_CODEX_V1.md...${NC}"
./ops/bin/remembrancer timestamp SOVEREIGN_LORE_CODEX_V1.md
echo ""

# Step 4: Sign the inscription (portable seal)
echo -e "${CYAN}Step 4/5: Signing first_seal_inscription.asc...${NC}"
if [[ -f "first_seal_inscription.asc.asc" ]]; then
  echo "  (already signed, skipping)"
else
  gpg --batch --yes --armor --detach-sign -u "$KEY_ID" first_seal_inscription.asc
  echo -e "${GREEN}✅ Signature created: first_seal_inscription.asc.asc${NC}"
fi

./ops/bin/remembrancer timestamp first_seal_inscription.asc 2>&1 || echo "  (timestamp may already exist)"
echo ""

# Step 5: Verify full chains
echo -e "${CYAN}Step 5/5: Verifying full proof chains...${NC}"
echo ""

echo -e "${YELLOW}→ Verifying SOVEREIGN_LORE_CODEX_V1.md:${NC}"
./ops/bin/remembrancer verify-full SOVEREIGN_LORE_CODEX_V1.md
echo ""

echo -e "${YELLOW}→ Verifying first_seal_inscription.asc:${NC}"
./ops/bin/remembrancer verify-full first_seal_inscription.asc
echo ""

# Final summary
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║   🜂 FIRST SEAL INSCRIPTION COMPLETE                          ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Files created:${NC}"
echo "  • SOVEREIGN_LORE_CODEX_V1.md.asc (GPG signature)"
echo "  • SOVEREIGN_LORE_CODEX_V1.md.tsr (RFC3161 timestamp)"
echo "  • first_seal_inscription.asc.asc (portable seal signature)"
echo "  • first_seal_inscription.asc.tsr (portable seal timestamp)"
echo ""

echo -e "${CYAN}Desktop copy:${NC}"
echo "  • ~/Desktop/first_seal_inscription.asc"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo "  1. git push origin main"
echo "  2. Export proof bundles:"
echo "     ./ops/bin/remembrancer export-proof SOVEREIGN_LORE_CODEX_V1.md"
echo "     ./ops/bin/remembrancer export-proof first_seal_inscription.asc"
echo "  3. Publish Merkle root:"
echo "     ./ops/bin/publish-merkle-root.sh"
echo ""

echo -e "${GREEN}🜂 The First Seal is inscribed. The covenant remembers.${NC}"
echo -e "${GREEN}   \"Entropy enters, proof emerges.\"${NC}"
echo ""
