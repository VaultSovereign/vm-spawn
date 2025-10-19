#!/usr/bin/env bash
# spawn-elite-complete.sh - COMPLETE Elite Spawn (base + elite features)
set -euo pipefail

REPO_NAME="${1:-}"
REPO_TYPE="${2:-service}"
REPO_BASE="${VAULTMESH_REPOS:-$HOME/repos}"

if [[ -z "$REPO_NAME" ]]; then
  echo "Usage: spawn-elite-complete.sh <name> [type]"
  echo "Example: spawn-elite-complete.sh payment-service service"
  exit 1
fi

# Step 1: Run base spawn
echo "═══════════════════════════════════════════════"
echo "🚀 STEP 1: Creating base repository..."
echo "═══════════════════════════════════════════════"
./spawn-linux.sh "$REPO_NAME" "$REPO_TYPE"

# Step 2: Add elite features
echo ""
echo "═══════════════════════════════════════════════"
echo "🔥 STEP 2: Adding ELITE features..."
echo "═══════════════════════════════════════════════"
./add-elite-features.sh "$REPO_BASE/$REPO_NAME"

# Done!
echo ""
echo "════════════════════════════════════════════════"
echo "🎉 ELITE REPOSITORY COMPLETE!"
echo "════════════════════════════════════════════════"
echo ""
echo "Location: $REPO_BASE/$REPO_NAME"
echo ""
echo "What you got:"
echo "  ✅ Complete base repository (FastAPI/tests/docs)"
echo "  ✅ GitHub Actions CI/CD"
echo "  ✅ Kubernetes manifests + HPA"
echo "  ✅ Docker Compose + monitoring stack"
echo "  ✅ Prometheus + Grafana configs"
echo "  ✅ Elite multi-stage Dockerfile"
echo ""
echo "Next steps:"
echo "  cd $REPO_BASE/$REPO_NAME"
echo "  make dev                  # Start development"
echo "  docker-compose up -d      # Full stack with monitoring"
echo "  make test                 # Run tests"
echo ""
