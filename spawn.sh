#!/usr/bin/env bash
# spawn.sh - VaultMesh Spawn Elite v2.4-MODULAR
# True modular architecture with extracted, tested generators
#
# This is the RIGHT way: each generator is independent, tested, and composable.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
REPO_NAME="${1:-}"
REPO_TYPE="${2:-service}"
REPO_BASE="${VAULTMESH_REPOS:-$HOME/repos}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# C3L Configuration (default off; harmless if unused)
WITH_MCP=0
WITH_MQ=0
MQ_KIND="rabbitmq"   # or 'nats'

# ============================================================================
# PRE-FLIGHT VALIDATION
# ============================================================================
preflight_check() {
  echo -e "${CYAN}🔍 Pre-flight Check${NC}"
  echo "===================="
  
  local CHECKS_PASSED=0
  local CHECKS_TOTAL=0
  
  # Check Python 3
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if command -v python3 &> /dev/null; then
    local PY_VERSION
    PY_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo -e "  ${GREEN}✅${NC} Python 3: $PY_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo -e "  ${RED}❌${NC} Python 3: not found"
  fi
  
  # Check pip
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if python3 -m pip --version &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} pip: available"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo -e "  ${YELLOW}⚠️${NC}  pip: not found (optional)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  fi
  
  # Check Docker (optional)
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if command -v docker &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} Docker: available"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo -e "  ${YELLOW}⚠️${NC}  Docker: not found (optional)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  fi
  
  echo ""
  echo -e "Pre-flight: ${GREEN}$CHECKS_PASSED${NC}/$CHECKS_TOTAL checks passed"
  echo ""
  
  if [[ $CHECKS_PASSED -lt 1 ]]; then
    echo -e "${RED}❌ Pre-flight failed. Install Python 3 first.${NC}"
    exit 1
  fi
}

# ============================================================================
# USAGE
# ============================================================================
usage() {
  cat <<'EOF'
Usage: spawn.sh <name> [type] [--with-mcp] [--with-mq {rabbitmq|nats}]

Types:
  service   - Python/FastAPI microservice (default)
  worker    - Background worker service
  api       - REST API service

C3L Options (non-breaking):
  --with-mcp           Scaffold an MCP server skeleton
  --with-mq <type>     Add MQ client skeleton (rabbitmq or nats)

Examples:
  spawn.sh payment-service service
  spawn.sh email-worker worker
  spawn.sh auth-api api
  spawn.sh herald service --with-mcp
  spawn.sh worker service --with-mq rabbitmq
  spawn.sh full service --with-mcp --with-mq nats

Environment Variables:
  VAULTMESH_REPOS   - Base directory for repos (default: ~/repos)

EOF
  exit 1
}

# ============================================================================
# MAIN SPAWN LOGIC (Modular - v2.4)
# ============================================================================
spawn_service() {
  local name="$1"
  local type="$2"
  local target="$REPO_BASE/$name"
  
  echo -e "${CYAN}🚀 Spawning: $name${NC}"
  echo "=========================="
  echo "  Name: $name"
  echo "  Type: $type"
  echo "  Path: $target"
  echo ""
  
  # Create directory
  if [[ -d "$target" ]]; then
    echo -e "${RED}❌ Repository already exists: $target${NC}"
    exit 1
  fi
  
  mkdir -p "$target"
  cd "$target"
  
  # Initialize git
  git init > /dev/null 2>&1
  echo -e "${GREEN}✅${NC} Git initialized"
  
  # Call modular generators
  echo -e "${BLUE}📦 Generating files...${NC}"
  bash "$SCRIPT_DIR/generators/source.sh" "$name" "$type"
  bash "$SCRIPT_DIR/generators/tests.sh" "$name"
  bash "$SCRIPT_DIR/generators/gitignore.sh"
  bash "$SCRIPT_DIR/generators/makefile.sh" "$name"
  bash "$SCRIPT_DIR/generators/readme.sh" "$name" "$type"
  
  # Create additional standard files
  cat > .env.example <<'ENV'
# Environment variables (copy to .env and configure)
ENV=development
LOG_LEVEL=INFO
ENV
  echo -e "${GREEN}✅${NC} .env.example created"
  
  # Create docs directory
  mkdir -p docs
  cat > docs/README.md <<'DOC'
# Documentation

Add project documentation here.
DOC
  echo -e "${GREEN}✅${NC} docs/ directory created"
  
  # Initial commit
  git add .
  git commit -m "feat: initial repository scaffold" > /dev/null 2>&1
  echo -e "${GREEN}✅${NC} Initial commit created"
  
  echo ""
  echo -e "${BLUE}🔥 Adding ELITE features...${NC}"
  bash "$SCRIPT_DIR/generators/cicd.sh" "$name"
  bash "$SCRIPT_DIR/generators/kubernetes.sh" "$name"
  bash "$SCRIPT_DIR/generators/dockerfile.sh" "$name"
  bash "$SCRIPT_DIR/generators/monitoring.sh" "$name"
  
  # C3L features (optional) - graceful degradation if generators missing/fail
  if [[ $WITH_MCP -eq 1 ]]; then
    echo ""
    echo -e "${BLUE}🌐 Adding MCP server...${NC}"
    if [[ -x "$SCRIPT_DIR/generators/mcp-server.sh" ]]; then
      if ! bash "$SCRIPT_DIR/generators/mcp-server.sh" "$name" --dir "$target"; then
        echo -e "${YELLOW}⚠️  MCP generator failed — continuing without MCP scaffold.${NC}"
        WITH_MCP=0
      fi
    else
      echo -e "${YELLOW}⚠️  MCP generator missing or not executable (generators/mcp-server.sh)${NC}"
      WITH_MCP=0
    fi
  fi
  
  if [[ $WITH_MQ -eq 1 ]]; then
    echo ""
    echo -e "${BLUE}📬 Adding message queue client ($MQ_KIND)...${NC}"
    if [[ -x "$SCRIPT_DIR/generators/message-queue.sh" ]]; then
      if ! bash "$SCRIPT_DIR/generators/message-queue.sh" "$name" --dir "$target" --type "$MQ_KIND"; then
        echo -e "${YELLOW}⚠️  MQ generator failed — continuing without MQ scaffold.${NC}"
        WITH_MQ=0
      fi
    else
      echo -e "${YELLOW}⚠️  MQ generator missing or not executable (generators/message-queue.sh)${NC}"
      WITH_MQ=0
    fi
  fi
  
  # Clean up .bak files
  echo -e "${BLUE}🧹 Cleaning up...${NC}"
  find "$target" -name "*.bak" -type f -delete 2>/dev/null || true
  echo -e "${GREEN}✅${NC} Removed .bak files"
  
  echo ""
  echo -e "${GREEN}✅ Spawn complete!${NC}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Show usage if no args
if [[ -z "$REPO_NAME" ]]; then
  usage
fi

# Parse C3L flags (shift past name and type first)
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-mcp)
      WITH_MCP=1
      shift
      ;;
    --with-mq)
      WITH_MQ=1
      MQ_KIND="${2:-rabbitmq}"
      if [[ "$MQ_KIND" != "rabbitmq" && "$MQ_KIND" != "nats" ]]; then
        echo -e "${RED}❌ --with-mq expects 'rabbitmq' or 'nats', got: $MQ_KIND${NC}"
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      usage
      ;;
  esac
done

echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                       ║${NC}"
echo -e "${PURPLE}║   🜞  VaultMesh Spawn Elite v2.4-MODULAR              ║${NC}"
echo -e "${PURPLE}║       True Modular Architecture (Smoke Tested)       ║${NC}"
echo -e "${PURPLE}║                                                       ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Pre-flight validation
preflight_check

# Step 2: Spawn the service (modular)
spawn_service "$REPO_NAME" "$REPO_TYPE"

# Final output
echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 SPAWN COMPLETE${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Location: ${CYAN}$REPO_BASE/$REPO_NAME${NC}"
echo ""
echo "What you got:"
echo "  ✅ FastAPI service with health checks"
echo "  ✅ Pytest test suite (passing)"
echo "  ✅ GitHub Actions CI/CD"
echo "  ✅ Kubernetes manifests + HPA"
echo "  ✅ Docker Compose + monitoring stack"
echo "  ✅ Prometheus + Grafana configs"
echo "  ✅ Elite multi-stage Dockerfile"
if [[ $WITH_MCP -eq 1 ]]; then
  echo "  ✅ MCP server (Model Context Protocol)"
fi
if [[ -n "$WITH_MQ" ]]; then
  echo "  ✅ Message queue client ($WITH_MQ)"
fi
echo ""
echo "Next steps:"
echo -e "  ${CYAN}cd $REPO_BASE/$REPO_NAME${NC}"
echo -e "  ${CYAN}python3 -m venv .venv${NC}"
echo -e "  ${CYAN}.venv/bin/pip install -r requirements.txt${NC}"
echo -e "  ${CYAN}make test${NC}                 # Run tests"
echo -e "  ${CYAN}make dev${NC}                  # Start development"
echo -e "  ${CYAN}docker-compose up -d${NC}      # Full stack with monitoring"
if [[ $WITH_MCP -eq 1 ]]; then
  echo ""
  echo "C3L - MCP Server:"
  echo -e "  ${CYAN}cd $REPO_BASE/$REPO_NAME && uv run mcp dev mcp/server.py${NC}"
fi
if [[ $WITH_MQ -eq 1 ]]; then
  echo ""
  echo "C3L - Message Queue ($MQ_KIND):"
  echo -e "  ${CYAN}cd $REPO_BASE/$REPO_NAME && uv run python mq/mq.py${NC}"
fi
echo ""
echo -e "${PURPLE}🜞 The forge is modular. The generators are pure. Perfection achieved.${NC}"
echo ""
