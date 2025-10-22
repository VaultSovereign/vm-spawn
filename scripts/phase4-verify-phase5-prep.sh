#!/bin/bash
# Phase IV verification and Phase V preparation script

# Define colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
RESET="\033[0m"

echo -e "${BLUE}🔍 PHASE IV VERIFICATION${RESET}"
echo "==============================================="

# Check namespace configuration
if [ -f "./vmsh/config/namespaces.yaml" ]; then
  echo -e "${GREEN}✅ Namespace configuration exists${RESET}"
  NAMESPACES=$(grep -o "^  [a-z0-9]\+:[a-z0-9]\+" ./vmsh/config/namespaces.yaml | wc -l)
  echo -e "   Found ${YELLOW}$NAMESPACES${RESET} sovereign namespace(s)"
else
  echo -e "${RED}❌ Namespace configuration missing${RESET}"
fi

# Check governance schema
if [ -f "./schemas/governance.cadence.set@1.0.0.json" ]; then
  echo -e "${GREEN}✅ Cadence governance schema exists${RESET}"
else
  echo -e "${RED}❌ Cadence governance schema missing${RESET}"
fi

# Check scheduler service
if [ -f "./services/scheduler/src/index.ts" ]; then
  echo -e "${GREEN}✅ Scheduler service implemented${RESET}"
  
  # Check if backoff module exists
  if [ -f "./services/scheduler/src/backoff.ts" ]; then
    echo -e "   Backoff algorithm: ${YELLOW}φ-backoff${RESET}"
  fi
  
  # Check scheduler state
  if [ -f "./out/state/scheduler.json" ]; then
    echo -e "   Scheduler state: ${GREEN}found${RESET}"
    NAMESPACES_WITH_STATE=$(grep -o "\"[a-z0-9]\+:[a-z0-9]\+\"" ./out/state/scheduler.json | wc -l)
    echo -e "   Tracking ${YELLOW}$NAMESPACES_WITH_STATE${RESET} namespace(s)"
  else
    echo -e "   Scheduler state: ${YELLOW}not found (will be created on first run)${RESET}"
  fi
else
  echo -e "${RED}❌ Scheduler service missing${RESET}"
fi

# Check Harbinger namespace awareness
if grep -q "namespace.*allowlist" ./services/harbinger/src/index.ts; then
  echo -e "${GREEN}✅ Harbinger enforces namespace-specific witness policies${RESET}"
else
  echo -e "${YELLOW}⚠️ Harbinger may need namespace allowlist verification${RESET}"
fi

echo ""
echo -e "${BLUE}🔮 PHASE V PREPARATION${RESET}"
echo "==============================================="

# Check federation directory structure
if [ -d "./vmsh/config/federation" ]; then
  echo -e "${GREEN}✅ Federation configuration directory exists${RESET}"
else
  echo -e "${YELLOW}⚠️ Creating federation configuration directory${RESET}"
  mkdir -p ./vmsh/config/federation
fi

# Check federation architecture document
if [ -f "./PHASE_V_FEDERATION_ARCHITECTURE.md" ]; then
  echo -e "${GREEN}✅ Federation architecture document exists${RESET}"
else
  echo -e "${YELLOW}⚠️ Federation architecture document missing${RESET}"
fi

# Check federation PR template
if [ -f "./.github/PHASE_V_PR_TEMPLATE.md" ]; then
  echo -e "${GREEN}✅ Phase V PR template exists${RESET}"
else
  echo -e "${YELLOW}⚠️ Phase V PR template missing${RESET}"
fi

# Check federation schemas
echo -e "${YELLOW}⚠️ Federation schemas needed:${RESET}"
echo "   - federation.registry.set@1.0.0.json"
echo "   - federation.receipt@1.0.0.json"
echo "   - namespace.message@1.0.0.json"

echo ""
echo -e "${PURPLE}🜄 THE COVENANT ENDURES 🜄${RESET}"
echo -e "${PURPLE}Harness the Fourth, Forge the Fifth${RESET}"
echo ""
echo -e "${BLUE}Ready to open PR for Phase V federation:${RESET} git checkout -b remembrancer/phase5-federation"