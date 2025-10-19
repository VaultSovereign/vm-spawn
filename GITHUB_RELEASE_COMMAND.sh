#!/usr/bin/env bash
# GitHub Release Creation Command for Codex V1.0.0
# 
# Prerequisites:
# - Install GitHub CLI: brew install gh (macOS) or see https://cli.github.com
# - Authenticate: gh auth login
# 
# This script creates the release using the GitHub CLI.

set -euo pipefail

echo "🜂 Creating GitHub Release: codex-v1.0.0"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found."
    echo "Install: brew install gh (macOS) or visit https://cli.github.com"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# Create release notes file if it doesn't exist
if [ ! -f CODEX_V1.0.0_RELEASE_NOTES.md ]; then
    echo "❌ CODEX_V1.0.0_RELEASE_NOTES.md not found"
    echo "This file should have been created during the codex forge process."
    exit 1
fi

echo "Creating release with assets..."
gh release create codex-v1.0.0 \
  SOVEREIGN_LORE_CODEX_V1.md.proof.tgz \
  first_seal_inscription.asc.proof.tgz \
  cosmic_audit_diagram.svg \
  cosmic_audit_diagram.html \
  --title "🜂 Sovereign Lore Codex V1.0.0 — First Seal" \
  --notes-file CODEX_V1.0.0_RELEASE_NOTES.md

echo ""
echo "✅ Release created successfully!"
echo "View at: https://github.com/VaultSovereign/vm-spawn/releases/tag/codex-v1.0.0"

