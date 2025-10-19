#!/usr/bin/env bash
# spawn-complete.sh - COMPLETE VaultMesh Elite Spawn System
# Actually generates ALL files documented

set -euo pipefail

# Configuration
VERSION="2.0.0-complete"
REPO_NAME="${1:-}"
REPO_TYPE="${2:-service}"
ENVIRONMENT="${3:-multi}"
REPO_BASE="${VAULTMESH_REPOS:-$HOME/repos}"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_info() { echo -e "${CYAN}[*]${NC} $*"; }

# Help
if [[ -z "$REPO_NAME" ]] || [[ "$REPO_NAME" == "-h" ]]; then
  cat << 'HELP'
VaultMesh Elite Spawn System - COMPLETE EDITION

Usage: spawn-complete.sh <name> [type] [env]

Types: service, infra, tool, platform
Environments: dev, staging, prod, multi

Example:
  ./spawn-complete.sh payment-service service multi
HELP
  exit 0
fi

REPO_DIR="$REPO_BASE/$REPO_NAME"
[[ -d "$REPO_DIR" ]] && { echo "❌ Repo exists: $REPO_DIR"; exit 1; }

log_info "Spawning $REPO_NAME (type: $REPO_TYPE, env: $ENVIRONMENT)"
mkdir -p "$REPO_DIR" && cd "$REPO_DIR"

# Git init
git init -q
log_success "Git initialized"

# Source all generator modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/generators/gitignore.sh"
source "$SCRIPT_DIR/generators/readme.sh"
source "$SCRIPT_DIR/generators/makefile.sh"
source "$SCRIPT_DIR/generators/dockerfile.sh"
source "$SCRIPT_DIR/generators/cicd.sh"
source "$SCRIPT_DIR/generators/kubernetes.sh"
source "$SCRIPT_DIR/generators/monitoring.sh"
source "$SCRIPT_DIR/generators/tests.sh"
source "$SCRIPT_DIR/generators/source.sh"

# Generate all files
generate_gitignore "$REPO_TYPE"
generate_readme "$REPO_NAME" "$REPO_TYPE" "$ENVIRONMENT"
generate_makefile "$REPO_TYPE"
generate_dockerfile "$REPO_NAME" "$REPO_TYPE"
generate_cicd "$REPO_NAME" "$REPO_TYPE"
generate_kubernetes "$REPO_NAME" "$REPO_TYPE" "$ENVIRONMENT"
generate_monitoring "$REPO_NAME"
generate_tests "$REPO_TYPE"
generate_source "$REPO_NAME" "$REPO_TYPE"

# Initial commit
git add .
git commit -m "feat: initial elite repository spawn

Type: $REPO_TYPE
Environment: $ENVIRONMENT
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" -q

log_success "Repository spawned: $REPO_DIR"
log_info "Next steps:"
log_info "  cd $REPO_DIR"
log_info "  make dev-setup"
log_info "  make test"
log_info "  make docker-build"

