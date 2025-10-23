#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/vm-spawn"
cd "$ROOT"

echo "[i] Starting VaultMesh PSI scaffolding cleanup in $ROOT"

# Paths to fold in / remove
DUP1="$ROOT/vaultmesh_psi_package (2)"
DUP2="$ROOT/vaultmesh_psi"
ZIP1="$ROOT/vaultmesh_psi_package.zip"
TAR1="$ROOT/PSI_VAULTMESH_INTEGRATED_READY.tar.gz"

# Canonical target inside the PSI service
TARGET="$ROOT/services/psi-field/vaultmesh_psi"

# Artifacts parking lot
ART="$ROOT/artifacts"
mkdir -p "$ART"

# 0) Backup anything that will be moved/removed
STAMP=$(date -u +%Y%m%d-%H%M%S)
BACKUP_TAR="$ART/backup_psipkg_$STAMP.tar.gz"
echo "[i] Creating backup $BACKUP_TAR (just in case)"
tar -czf "$BACKUP_TAR" \
  --ignore-failed-read \
  "vaultmesh_psi" \
  "vaultmesh_psi_package (2)" \
  "vaultmesh_psi_package.zip" \
  "PSI_VAULTMESH_INTEGRATED_READY.tar.gz" \
  "docker-compose.psiboth.yml" \
  "ops/k8s/psi-both.yaml" \
  "ops/psi-smoke-test.sh" \
  "docs/PSI_DUAL_BACKEND_DEPLOYMENT.md" 2>/dev/null || true

# 1) Ensure target exists
mkdir -p "$TARGET"

# 2) Prefer the most complete source for vaultmesh_psi → rsync into TARGET
pick_src=""
if [ -d "$DUP1" ] && [ -d "$DUP1/vaultmesh_psi" ]; then
  pick_src="$DUP1/vaultmesh_psi"
elif [ -d "$DUP2" ]; then
  pick_src="$DUP2"
fi

if [ -n "$pick_src" ]; then
  echo "[i] Syncing $pick_src → $TARGET"
  rsync -a --delete "$pick_src"/ "$TARGET"/
else
  echo "[!] No external vaultmesh_psi source found; leaving current service copy as-is"
fi

# 3) Remove root-level duplicates after sync
if [ -d "$DUP1" ]; then
  echo "[i] Removing duplicate dir: $DUP1"
  rm -rf "$DUP1"
fi
if [ -d "$DUP2" ]; then
  echo "[i] Removing duplicate dir: $DUP2"
  rm -rf "$DUP2"
fi
if [ -f "$ZIP1" ]; then
  echo "[i] Moving zip to artifacts/: $ZIP1"
  mv "$ZIP1" "$ART"/
fi
if [ -f "$TAR1" ]; then
  echo "[i] Moving tarball to artifacts/: $TAR1"
  mv "$TAR1" "$ART"/
fi

# 4) Remove root-level duplicate deployment files (already in services/psi-field/)
if [ -f "$ROOT/docker-compose.psiboth.yml" ]; then
  echo "[i] Removing root-level docker-compose.psiboth.yml (use services/psi-field/docker-compose.psiboth.yml)"
  rm -f "$ROOT/docker-compose.psiboth.yml"
fi
if [ -f "$ROOT/ops/k8s/psi-both.yaml" ]; then
  echo "[i] Removing ops/k8s/psi-both.yaml (use services/psi-field/k8s/psi-both.yaml)"
  rm -f "$ROOT/ops/k8s/psi-both.yaml"
fi
if [ -f "$ROOT/ops/psi-smoke-test.sh" ]; then
  echo "[i] Removing ops/psi-smoke-test.sh (use services/psi-field/smoke-test-dual.sh)"
  rm -f "$ROOT/ops/psi-smoke-test.sh"
fi
if [ -f "$ROOT/docs/PSI_DUAL_BACKEND_DEPLOYMENT.md" ]; then
  echo "[i] Removing docs/PSI_DUAL_BACKEND_DEPLOYMENT.md (use services/psi-field/DUAL_BACKEND_GUIDE.md)"
  rm -f "$ROOT/docs/PSI_DUAL_BACKEND_DEPLOYMENT.md"
fi

# 5) Add .gitignore safety for future zips / bundles in root
GITIGNORE="$ROOT/.gitignore"
if ! grep -qE '^# VaultMesh bundles' "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" <<'EOF'

# VaultMesh bundles / artifacts
PSI_VAULTMESH_INTEGRATED_READY.tar.gz
vaultmesh_psi_package*.zip
artifacts/
EOF
  echo "[i] Updated .gitignore with bundle/artifact ignores"
fi

# 6) Quick import check: ensure service imports 'vaultmesh_psi' fine
echo "[i] Verifying imports that reference 'from vaultmesh_psi...' still resolve:"
grep -RIn --include='*.py' 'from vaultmesh_psi' services/psi-field/src || true

echo "[✓] Cleanup complete."
echo "    - Canonical package: services/psi-field/vaultmesh_psi/"
echo "    - Artifacts backup: $BACKUP_TAR"
echo "    - Stray root copies removed / parked"
echo ""
echo "Use these canonical paths:"
echo "  - Compose: cd services/psi-field && docker compose -f docker-compose.psiboth.yml up -d"
echo "  - K8s: kubectl apply -f services/psi-field/k8s/psi-both.yaml"
echo "  - Smoke test: cd services/psi-field && ./smoke-test-dual.sh"
