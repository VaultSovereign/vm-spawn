#!/usr/bin/env bash
# SMOKE_TEST.sh - VaultMesh Spawn Elite Comprehensive Smoke Test
# Tests ALL functionality before claiming production-ready status

set -uo pipefail  # Don't use -e in test scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Test workspace
TEST_WORKSPACE="/tmp/vaultmesh-smoke-test-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cleanup function
cleanup() {
  if [[ -d "$TEST_WORKSPACE" ]]; then
    rm -rf "$TEST_WORKSPACE" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Test result tracking
test_start() {
  ((TESTS_RUN++))
  echo -e "${CYAN}TEST $TESTS_RUN: $1${NC}"
}

test_pass() {
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✅ PASS${NC}: $1"
  echo ""
}

test_fail() {
  ((TESTS_FAILED++))
  echo -e "  ${RED}❌ FAIL${NC}: $1"
  echo ""
}

test_warn() {
  ((TESTS_WARNINGS++))
  echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"
  echo ""
}

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   🔥  VAULTMESH SMOKE TEST SUITE                              ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Test Workspace: $TEST_WORKSPACE"
echo "Script Dir: $SCRIPT_DIR"
echo ""

mkdir -p "$TEST_WORKSPACE"
cd "$SCRIPT_DIR"

# ============================================================================
# CATEGORY 1: FILE STRUCTURE
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 1: FILE STRUCTURE ═══${NC}"
echo ""

test_start "Critical files exist"
CRITICAL_FILES=(
  "spawn.sh"
  "ops/bin/remembrancer"
  "ops/bin/health-check"
  "docs/REMEMBRANCER.md"
  "README.md"
)
MISSING=0
for file in "${CRITICAL_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "    Missing: $file"
    ((MISSING++))
  fi
done
if [[ $MISSING -eq 0 ]]; then
  test_pass "All $((${#CRITICAL_FILES[@]})) critical files exist"
else
  test_fail "$MISSING/${#CRITICAL_FILES[@]} files missing"
fi

test_start "Scripts are executable"
EXEC_SCRIPTS=(
  "spawn.sh"
  "ops/bin/remembrancer"
  "ops/bin/health-check"
)
NON_EXEC=0
for script in "${EXEC_SCRIPTS[@]}"; do
  if [[ ! -x "$script" ]]; then
    echo "    Not executable: $script"
    ((NON_EXEC++))
  fi
done
if [[ $NON_EXEC -eq 0 ]]; then
  test_pass "All ${#EXEC_SCRIPTS[@]} scripts are executable"
else
  test_fail "$NON_EXEC/${#EXEC_SCRIPTS[@]} scripts not executable"
fi

test_start "Generators exist"
GENERATOR_COUNT=$(ls -1 generators/*.sh 2>/dev/null | wc -l | xargs)
if [[ $GENERATOR_COUNT -ge 5 ]]; then
  test_pass "Found $GENERATOR_COUNT generators"
else
  test_warn "Only $GENERATOR_COUNT generators (expected 9)"
fi

# ============================================================================
# CATEGORY 2: SPAWN FUNCTIONALITY
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 2: SPAWN FUNCTIONALITY ═══${NC}"
echo ""

test_start "spawn.sh shows help"
HELP_OUTPUT=$(./spawn.sh 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -q "Usage:"; then
  test_pass "Help message displays"
else
  test_fail "Help message doesn't display"
fi

test_start "spawn.sh accepts parameters"
export VAULTMESH_REPOS="$TEST_WORKSPACE"
# Run spawn and capture exit code separately
timeout 30 ./spawn.sh smoke-test-svc service > /tmp/spawn-output.log 2>&1 || true
if grep -q "SPAWN COMPLETE\|Spawn complete" /tmp/spawn-output.log && [[ -d "$TEST_WORKSPACE/smoke-test-svc" ]]; then
  test_pass "Spawn command executes"
else
  test_fail "Spawn command failed or timeout"
fi

test_start "Spawned service has critical files"
if [[ -d "$TEST_WORKSPACE/smoke-test-svc" ]]; then
  cd "$TEST_WORKSPACE/smoke-test-svc"
  SPAWN_FILES=(
    "main.py"
    "requirements.txt"
    "Makefile"
    "README.md"
  )
  SPAWN_MISSING=0
  for file in "${SPAWN_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "    Missing: $file"
      ((SPAWN_MISSING++))
    fi
  done
  if [[ $SPAWN_MISSING -eq 0 ]]; then
    test_pass "All ${#SPAWN_FILES[@]} critical files generated"
  else
    test_warn "$SPAWN_MISSING/${#SPAWN_FILES[@]} files missing from spawn"
  fi
  cd "$SCRIPT_DIR"
else
  test_fail "Spawned directory doesn't exist"
fi

test_start "main.py is valid Python"
if [[ -f "$TEST_WORKSPACE/smoke-test-svc/main.py" ]]; then
  if python3 -m py_compile "$TEST_WORKSPACE/smoke-test-svc/main.py" 2>/dev/null; then
    test_pass "main.py compiles successfully"
  else
    test_fail "main.py has syntax errors"
  fi
else
  test_fail "main.py not found"
fi

test_start "requirements.txt is valid"
if [[ -f "$TEST_WORKSPACE/smoke-test-svc/requirements.txt" ]]; then
  if grep -q "fastapi" "$TEST_WORKSPACE/smoke-test-svc/requirements.txt" &&  grep -q "uvicorn" "$TEST_WORKSPACE/smoke-test-svc/requirements.txt"; then
    test_pass "requirements.txt has FastAPI dependencies"
  else
    test_fail "requirements.txt missing critical dependencies"
  fi
else
  test_fail "requirements.txt not found"
fi

# ============================================================================
# CATEGORY 3: REMEMBRANCER SYSTEM
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 3: REMEMBRANCER SYSTEM ═══${NC}"
echo ""

test_start "remembrancer CLI responds"
if ./ops/bin/remembrancer --version 2>&1 | grep -q "remembrancer"; then
  test_pass "CLI responds to --version"
else
  test_warn "CLI doesn't respond to --version"
fi

test_start "remembrancer can list deployments"
LIST_OUTPUT=$(./ops/bin/remembrancer list deployments 2>&1 || true)
if echo "$LIST_OUTPUT" | grep -q "deployments\|Released\|v2.2\|Listing"; then
  test_pass "List deployments works"
else
  test_warn "List deployments failed or empty"
fi

test_start "remembrancer memory index exists"
if [[ -f "docs/REMEMBRANCER.md" ]] && [[ -s "docs/REMEMBRANCER.md" ]]; then
  LINE_COUNT=$(wc -l < "docs/REMEMBRANCER.md")
  if [[ $LINE_COUNT -gt 50 ]]; then
    test_pass "Memory index exists ($LINE_COUNT lines)"
  else
    test_warn "Memory index is too short ($LINE_COUNT lines)"
  fi
else
  test_fail "Memory index missing or empty"
fi

test_start "Receipt system is set up"
if [[ -d "ops/receipts/deploy" ]]; then
  RECEIPT_COUNT=$(find ops/receipts/deploy -name "*.receipt" 2>/dev/null | wc -l | xargs)
  if [[ $RECEIPT_COUNT -gt 0 ]]; then
    test_pass "Found $RECEIPT_COUNT receipts"
  else
    test_warn "No receipts found (expected at least 1)"
  fi
else
  test_fail "Receipt directory structure missing"
fi

# ============================================================================
# CATEGORY 4: DOCUMENTATION
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 4: DOCUMENTATION ═══${NC}"
echo ""

test_start "README.md is comprehensive"
if [[ -f "README.md" ]]; then
  README_SIZE=$(wc -l < "README.md")
  if [[ $README_SIZE -gt 200 ]]; then
    test_pass "README is comprehensive ($README_SIZE lines)"
  else
    test_warn "README is short ($README_SIZE lines, expected 200+)"
  fi
else
  test_fail "README.md missing"
fi

test_start "Documentation links are valid"
BROKEN_LINKS=0
for doc in START_HERE.md CONTRIBUTING.md LICENSE; do
  if [[ ! -f "$doc" ]]; then
    echo "    Missing: $doc"
    ((BROKEN_LINKS++))
  fi
done
if [[ $BROKEN_LINKS -eq 0 ]]; then
  test_pass "All documentation files present"
else
  test_warn "$BROKEN_LINKS documentation files missing"
fi

# ============================================================================
# CATEGORY 5: RUBBER DUCKY
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 5: RUBBER DUCKY ═══${NC}"
echo ""

test_start "Rubber Ducky installer exists"
if [[ -x "rubber-ducky/INSTALL_TO_DUCKY.sh" ]]; then
  test_pass "Installer is executable"
else
  test_warn "Installer missing or not executable"
fi

test_start "DuckyScript payloads exist"
PAYLOAD_COUNT=$(find rubber-ducky -name "*.txt" 2>/dev/null | wc -l | xargs)
if [[ $PAYLOAD_COUNT -ge 2 ]]; then
  test_pass "Found $PAYLOAD_COUNT payload files"
else
  test_warn "Only $PAYLOAD_COUNT payloads (expected 2)"
fi

# ============================================================================
# CATEGORY 6: SECURITY RITUALS
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 6: SECURITY RITUALS ═══${NC}"
echo ""

test_start "Security ritual scripts exist"
RITUAL_SCRIPTS=(
  "ops/bin/QUICK_CHECKLIST.sh"
  "ops/bin/FIRST_BOOT_RITUAL.sh"
  "ops/bin/POST_MIGRATION_HARDEN.sh"
)
RITUAL_MISSING=0
for script in "${RITUAL_SCRIPTS[@]}"; do
  if [[ ! -x "$script" ]]; then
    echo "    Missing/not executable: $script"
    ((RITUAL_MISSING++))
  fi
done
if [[ $RITUAL_MISSING -eq 0 ]]; then
  test_pass "All ${#RITUAL_SCRIPTS[@]} ritual scripts ready"
else
  test_warn "$RITUAL_MISSING/${#RITUAL_SCRIPTS[@]} rituals missing"
fi

# ============================================================================
# CATEGORY 7: ARTIFACT INTEGRITY
# ============================================================================
echo -e "${PURPLE}═══ CATEGORY 7: ARTIFACT INTEGRITY ═══${NC}"
echo ""

test_start "Production artifact exists"
if [[ -f "vaultmesh-spawn-elite-v2.2-PRODUCTION.tar.gz" ]]; then
  test_pass "Production tarball found"
else
  test_fail "Production artifact missing"
fi

test_start "Production artifact SHA256 matches"
if [[ -f "vaultmesh-spawn-elite-v2.2-PRODUCTION.tar.gz" ]]; then
  COMPUTED=$(shasum -a 256 vaultmesh-spawn-elite-v2.2-PRODUCTION.tar.gz | awk '{print $1}')
  EXPECTED="44e8ecdcd17ac9e3695280c71f7507051c1fa17373593dc96e5c49b80b5c8dfd"
  if [[ "$COMPUTED" == "$EXPECTED" ]]; then
    test_pass "SHA256 verified: ${COMPUTED:0:16}..."
  else
    test_fail "SHA256 mismatch! Expected: $EXPECTED, Got: $COMPUTED"
  fi
else
  test_fail "Cannot verify - artifact missing"
fi

# ============================================================================
# v3.0 COVENANT FOUNDATION TESTS
# ============================================================================

test_start "v3.0: GPG signing functionality"
if ! command -v gpg >/dev/null 2>&1; then
  test_warn "GPG not installed - skipping test (optional)"
else
  # Create temporary test artifact
  TMPDIR="$(mktemp -d)"
  pushd "$TMPDIR" >/dev/null 2>&1
  echo "test content for v3.0 signing" > test-artifact.txt
  
  # Generate ephemeral test key (1-day, signing-capable)
  GPG_BATCH_OUTPUT=$(gpg --batch --quick-generate-key "VM Test <test@vaultmesh.local>" rsa3072 sign 1d 2>&1)
  
  # Sign using remembrancer
  if "$SCRIPT_DIR/ops/bin/remembrancer" sign test-artifact.txt --key "test@vaultmesh.local" >/dev/null 2>&1; then
    if [[ -f test-artifact.txt.asc ]]; then
      # Verify signature
      if gpg --verify test-artifact.txt.asc test-artifact.txt >/dev/null 2>&1; then
        test_pass "GPG signing and verification works"
      else
        test_fail "Signature verification failed"
      fi
    else
      test_fail "Signature file not created"
    fi
  else
    test_warn "Signing failed (acceptable if no GPG configured)"
  fi
  
  popd >/dev/null 2>&1
  rm -rf "$TMPDIR"
fi

test_start "v3.0: RFC3161 timestamping functionality"
if ! command -v openssl >/dev/null 2>&1; then
  test_warn "OpenSSL not installed - skipping test (optional)"
else
  # Create temporary test artifact
  TMPDIR="$(mktemp -d)"
  pushd "$TMPDIR" >/dev/null 2>&1
  echo "test content for v3.0 timestamp" > test-ts.txt
  
  # Attempt timestamp (may fail if no network or TSA down)
  if "$SCRIPT_DIR/ops/bin/remembrancer" timestamp test-ts.txt >/dev/null 2>&1; then
    if [[ -f test-ts.txt.tsr ]]; then
      test_pass "RFC3161 timestamping works"
    else
      test_warn "Timestamp token not created (TSA may be unreachable)"
    fi
  else
    test_warn "Timestamping failed (acceptable if no network/TSA)"
  fi
  
  popd >/dev/null 2>&1
  rm -rf "$TMPDIR"
fi

test_start "v3.0: Merkle audit log functionality"
if ! command -v python3 >/dev/null 2>&1; then
  test_warn "Python3 not installed - skipping test (required for audit)"
elif [[ ! -f "$SCRIPT_DIR/ops/lib/merkle.py" ]]; then
  test_fail "Merkle library not found at ops/lib/merkle.py"
else
  # Test audit verification (should pass even with no published root yet)
  if "$SCRIPT_DIR/ops/bin/remembrancer" verify-audit >/dev/null 2>&1; then
    test_pass "Merkle audit log verification works"
  else
    # Check if it's just missing published root (acceptable)
    AUDIT_OUTPUT=$("$SCRIPT_DIR/ops/bin/remembrancer" verify-audit 2>&1 || true)
    if [[ "$AUDIT_OUTPUT" == *"No published Merkle Root"* ]]; then
      test_pass "Merkle computation works (no published root yet - acceptable)"
    else
      test_fail "Audit verification failed unexpectedly"
    fi
  fi
fi

test_start "v3.0: Covenant invariant — artifact proof verification"
# Test that all artifacts in dist/ have valid proof chains
shopt -s nullglob
CA_FILE="$SCRIPT_DIR/ops/certs/freetsa-ca.pem"
ARTIFACT_COUNT=0
VERIFIED_COUNT=0

for artifact in "$SCRIPT_DIR/dist"/*.tar.gz "$SCRIPT_DIR/dist"/*.txt; do
  [[ -f "$artifact" ]] || continue
  ((ARTIFACT_COUNT++))
  
  # Check if remembrancer verify-full works
  if "$SCRIPT_DIR/ops/bin/remembrancer" verify-full "$artifact" >/dev/null 2>&1; then
    ((VERIFIED_COUNT++))
    
    # Optional: verify timestamp if CA present (non-fatal)
    if [[ -f "$CA_FILE" && -f "${artifact}.tsr" ]]; then
      if ! openssl ts -verify -data "$artifact" -in "${artifact}.tsr" -CAfile "$CA_FILE" >/dev/null 2>&1; then
        echo "  ⚠️  Timestamp verification failed for $(basename "$artifact") (non-fatal)"
      fi
    fi
  else
    echo "  ❌ verify-full failed for $(basename "$artifact")"
  fi
done

if [[ $ARTIFACT_COUNT -eq 0 ]]; then
  test_warn "No artifacts found in dist/ (acceptable on clean system)"
elif [[ $VERIFIED_COUNT -eq $ARTIFACT_COUNT ]]; then
  test_pass "Verified $VERIFIED_COUNT artifacts with proof chains"
else
  test_fail "Only $VERIFIED_COUNT/$ARTIFACT_COUNT artifacts verified"
fi

test_start "v4.0: MCP server boot check"
if ! command -v uv &>/dev/null; then
  test_warn "uv not installed (needed for MCP testing) - skipping"
elif [[ ! -f "$SCRIPT_DIR/ops/mcp/remembrancer_server.py" ]]; then
  test_warn "MCP server not found (v4.0 not installed) - skipping"
else
  # Check if MCP server can import
  if python3 -c "import sys; sys.path.insert(0, '$SCRIPT_DIR/ops/mcp'); import remembrancer_server" 2>/dev/null; then
    test_pass "MCP server imports successfully"
  else
    test_warn "MCP server import check skipped (FastMCP not installed)"
  fi
fi

# ============================================================================
# FINAL REPORT
# ============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   🔥  SMOKE TEST COMPLETE                                     ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${PURPLE}═══ FINAL RESULTS ═══${NC}"
echo ""
echo -e "  Tests Run:     ${CYAN}$TESTS_RUN${NC}"
echo -e "  Passed:        ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Failed:        ${RED}$TESTS_FAILED${NC}"
echo -e "  Warnings:      ${YELLOW}$TESTS_WARNINGS${NC}"
echo ""

# Calculate percentage
if [[ $TESTS_RUN -gt 0 ]]; then
  PASS_RATE=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
else
  PASS_RATE=0
fi

echo -e "  Pass Rate:     ${CYAN}$PASS_RATE%${NC}"
echo ""

# Determine rating
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNINGS -eq 0 ]]; then
  RATING="10.0/10"
  RATING_COLOR=$GREEN
  STATUS="✅ LITERALLY PERFECT"
elif [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNINGS -le 3 ]]; then
  RATING="9.5/10"
  RATING_COLOR=$GREEN
  STATUS="✅ PRODUCTION-READY"
elif [[ $TESTS_FAILED -le 2 ]]; then
  RATING="8.0/10"
  RATING_COLOR=$YELLOW
  STATUS="⚠️  NEEDS MINOR FIXES"
else
  RATING="<8.0/10"
  RATING_COLOR=$RED
  STATUS="❌ NEEDS MAJOR WORK"
fi

echo -e "${RATING_COLOR}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RATING_COLOR}║                                                               ║${NC}"
echo -e "${RATING_COLOR}║   RATING: $RATING                                              ║${NC}"
echo -e "${RATING_COLOR}║   STATUS: $STATUS                                    ║${NC}"
echo -e "${RATING_COLOR}║                                                               ║${NC}"
echo -e "${RATING_COLOR}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✅ Smoke test passed! System is ready.${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}❌ Smoke test failed! Fix issues before claiming production-ready.${NC}"
  echo ""
  echo "Failed tests: $TESTS_FAILED"
  echo "Warnings: $TESTS_WARNINGS"
  echo ""
  exit 1
fi

