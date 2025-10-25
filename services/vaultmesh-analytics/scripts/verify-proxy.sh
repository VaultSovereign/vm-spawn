#!/usr/bin/env bash
# Verification script for VaultMesh Analytics API proxy configuration
# Tests that Next.js rewrites correctly proxy to psi-field and aurora-router

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="vaultmesh"
SERVICE="vaultmesh-analytics"
LOCAL_PORT=3300
TIMEOUT=120

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  VaultMesh Analytics API Proxy Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Wait for kubectl to be responsive
echo -e "${YELLOW}[1/5] Checking kubectl connectivity...${NC}"
RETRIES=0
MAX_RETRIES=12
until kubectl cluster-info &> /dev/null; do
  RETRIES=$((RETRIES+1))
  if [ $RETRIES -ge $MAX_RETRIES ]; then
    echo -e "${RED}✗ kubectl not responding after ${MAX_RETRIES} attempts${NC}"
    echo -e "${YELLOW}  This is likely a GKE auth token refresh cycle issue${NC}"
    echo -e "${YELLOW}  Try: gcloud container clusters get-credentials vaultmesh-minimal --region=us-central1 --project=vm-spawn${NC}"
    exit 1
  fi
  echo -e "  Waiting for kubectl... (attempt $RETRIES/$MAX_RETRIES)"
  sleep 10
done
echo -e "${GREEN}✓ kubectl is responsive${NC}"
echo ""

# Step 2: Check deployment rollout status
echo -e "${YELLOW}[2/5] Checking Analytics deployment rollout status...${NC}"
if kubectl rollout status deployment/${SERVICE} -n ${NAMESPACE} --timeout=${TIMEOUT}s; then
  echo -e "${GREEN}✓ Analytics deployment is ready${NC}"
else
  echo -e "${RED}✗ Analytics deployment rollout did not complete${NC}"
  exit 1
fi
echo ""

# Step 3: Verify environment variables in pods
echo -e "${YELLOW}[3/5] Verifying environment variables in pods...${NC}"
POD=$(kubectl get pod -n ${NAMESPACE} -l app=${SERVICE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD" ]; then
  echo -e "${RED}✗ No Analytics pods found${NC}"
  exit 1
fi

echo -e "  Pod: ${POD}"
PSI_URL=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].env[?(@.name=="PSI_FIELD_URL")].value}' 2>/dev/null || echo "NOT_SET")
AURORA_URL=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].env[?(@.name=="AURORA_ROUTER_URL")].value}' 2>/dev/null || echo "NOT_SET")

echo -e "  PSI_FIELD_URL: ${PSI_URL}"
echo -e "  AURORA_ROUTER_URL: ${AURORA_URL}"

if [[ "$PSI_URL" == "http://psi-field:8000" ]]; then
  echo -e "${GREEN}✓ PSI_FIELD_URL correctly configured${NC}"
else
  echo -e "${RED}✗ PSI_FIELD_URL incorrect: ${PSI_URL}${NC}"
  exit 1
fi

if [[ "$AURORA_URL" == "http://aurora-router:8080" ]]; then
  echo -e "${GREEN}✓ AURORA_ROUTER_URL correctly configured${NC}"
else
  echo -e "${YELLOW}⚠ AURORA_ROUTER_URL: ${AURORA_URL} (aurora-router not deployed yet)${NC}"
fi
echo ""

# Step 4: Start port-forward
echo -e "${YELLOW}[4/5] Starting port-forward to localhost:${LOCAL_PORT}...${NC}"
kubectl port-forward -n ${NAMESPACE} svc/${SERVICE} ${LOCAL_PORT}:3000 > /dev/null 2>&1 &
PF_PID=$!

# Trap to ensure port-forward cleanup
cleanup() {
  if [ ! -z "${PF_PID:-}" ]; then
    echo ""
    echo -e "${YELLOW}Cleaning up port-forward (PID: ${PF_PID})...${NC}"
    kill ${PF_PID} 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Wait for port-forward to be ready
echo -e "  Waiting for port-forward to be ready..."
sleep 3

# Test if port-forward is working
if ! curl -s -f http://localhost:${LOCAL_PORT} > /dev/null 2>&1; then
  echo -e "${RED}✗ Port-forward not working${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Port-forward established (PID: ${PF_PID})${NC}"
echo ""

# Step 5: Test API proxy endpoints
echo -e "${YELLOW}[5/5] Testing API proxy endpoints...${NC}"

# Test psi-field proxy
echo -e "  Testing /api/psi-field/health..."
PSI_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:${LOCAL_PORT}/api/psi-field/health 2>/dev/null || echo -e "\n000")
PSI_BODY=$(echo "$PSI_RESPONSE" | head -n -1)
PSI_CODE=$(echo "$PSI_RESPONSE" | tail -n 1)

if [[ "$PSI_CODE" == "200" ]]; then
  echo -e "${GREEN}✓ Psi-field API proxy working (HTTP ${PSI_CODE})${NC}"
  echo -e "    Response: ${PSI_BODY}" | head -c 100
  echo ""
else
  echo -e "${RED}✗ Psi-field API proxy failed (HTTP ${PSI_CODE})${NC}"
  echo -e "    Response: ${PSI_BODY}" | head -c 200
  echo ""
fi

# Test aurora-router proxy (expected to fail since aurora-router isn't deployed)
echo -e "  Testing /api/aurora-router/health..."
AURORA_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:${LOCAL_PORT}/api/aurora-router/health 2>/dev/null || echo -e "\n000")
AURORA_CODE=$(echo "$AURORA_RESPONSE" | tail -n 1)

if [[ "$AURORA_CODE" == "200" ]]; then
  echo -e "${GREEN}✓ Aurora Router API proxy working (HTTP ${AURORA_CODE})${NC}"
else
  echo -e "${YELLOW}⚠ Aurora Router API proxy not available (HTTP ${AURORA_CODE}) - service not deployed yet${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$PSI_CODE" == "200" ]]; then
  echo -e "${GREEN}✓ Verification PASSED${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Analytics dashboard: http://localhost:${LOCAL_PORT}"
  echo "Psi-field API proxy: http://localhost:${LOCAL_PORT}/api/psi-field/health"
  echo ""
  echo "Port-forward is still running (PID: ${PF_PID})"
  echo "Press Ctrl+C to stop port-forward and exit"

  # Keep running until user interrupts
  wait ${PF_PID}
else
  echo -e "${RED}✗ Verification FAILED${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 1
fi
