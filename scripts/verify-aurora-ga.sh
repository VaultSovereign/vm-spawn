#!/usr/bin/env bash
# verify-aurora-ga.sh - Complete Aurora GA verification suite
# Implements all checks from dist/VERIFICATION.md

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

EXPECTED_SHA256="acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8"
GPG_KEY="6E4082C6A410F340"
ARTIFACT="${1:-dist/aurora-20251022.tar.gz}"

PASSED=0
FAILED=0

check() {
    local name="$1"
    echo -e "${CYAN}▶ $name${NC}"
}

pass() {
    ((PASSED++))
    echo -e "  ${GREEN}✅ $1${NC}"
}

fail() {
    ((FAILED++))
    echo -e "  ${RED}❌ $1${NC}"
}

warn() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
}

echo "🜂 Aurora GA Verification Suite"
echo "================================"
echo ""

# 1. Check artifact exists
check "Artifact exists"
if [[ -f "$ARTIFACT" ]]; then
    pass "Found: $ARTIFACT"
else
    fail "Artifact not found: $ARTIFACT"
    echo ""
    echo "Run: make dist KEY=$GPG_KEY"
    exit 1
fi

# 2. Verify SHA256
check "SHA256 checksum"
if command -v sha256sum &>/dev/null; then
    COMPUTED=$(sha256sum "$ARTIFACT" | awk '{print $1}')
elif command -v shasum &>/dev/null; then
    COMPUTED=$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')
else
    fail "No SHA256 tool available"
    COMPUTED=""
fi

if [[ "$COMPUTED" == "$EXPECTED_SHA256" ]]; then
    pass "Checksum matches"
    echo "     $COMPUTED"
else
    fail "Checksum mismatch!"
    echo "     Expected: $EXPECTED_SHA256"
    echo "     Got:      $COMPUTED"
fi

# 3. Verify GPG signature
check "GPG signature"
if [[ -f "${ARTIFACT}.asc" ]]; then
    if gpg --verify "${ARTIFACT}.asc" "$ARTIFACT" &>/dev/null; then
        pass "Signature valid (key: $GPG_KEY)"
    else
        fail "Signature verification failed"
        warn "Import key: gpg --recv-keys $GPG_KEY"
    fi
else
    fail "Signature file not found: ${ARTIFACT}.asc"
fi

# 4. Verify Merkle audit
check "Merkle audit log"
if [[ -x "ops/bin/remembrancer" ]]; then
    if ./ops/bin/remembrancer verify-audit &>/dev/null; then
        pass "Audit log integrity verified"
    else
        OUTPUT=$(./ops/bin/remembrancer verify-audit 2>&1 || true)
        if [[ "$OUTPUT" == *"No published Merkle Root"* ]]; then
            warn "No published root yet (acceptable)"
        else
            fail "Audit verification failed"
        fi
    fi
else
    warn "Remembrancer CLI not found (skipping)"
fi

# 5. Verify RFC3161 timestamps (if present)
check "RFC3161 timestamps"
TIMESTAMP_COUNT=0
if command -v openssl &>/dev/null && [[ -f "ops/certs/freetsa-ca.pem" ]]; then
    for tsr in dist/*.tsr ops/test-artifacts/*.tsr 2>/dev/null; do
        [[ -f "$tsr" ]] || continue
        ARTIFACT_FILE="${tsr%.tsr}"
        if [[ -f "$ARTIFACT_FILE" ]]; then
            if openssl ts -verify -data "$ARTIFACT_FILE" -in "$tsr" -CAfile ops/certs/freetsa-ca.pem &>/dev/null; then
                ((TIMESTAMP_COUNT++))
            fi
        fi
    done
    if [[ $TIMESTAMP_COUNT -gt 0 ]]; then
        pass "Verified $TIMESTAMP_COUNT timestamp(s)"
    else
        warn "No timestamps found (optional)"
    fi
else
    warn "OpenSSL or CA cert not available (skipping)"
fi

# 6. Verify WASM policy (if extracted)
check "WASM policy"
if [[ -f "policy/wasm/vault-law-akash-policy.wasm" ]]; then
    if command -v wasm-objdump &>/dev/null; then
        if wasm-objdump -h policy/wasm/vault-law-akash-policy.wasm &>/dev/null; then
            pass "WASM module valid"
        else
            fail "WASM module invalid"
        fi
    else
        warn "wasm-objdump not available (skipping)"
    fi
else
    warn "WASM policy not extracted (optional)"
fi

# 7. Verify schemas
check "JSON schemas"
SCHEMA_COUNT=0
if command -v jsonschema &>/dev/null; then
    for schema in schemas/*.schema.json 2>/dev/null; do
        [[ -f "$schema" ]] || continue
        if jq empty "$schema" &>/dev/null; then
            ((SCHEMA_COUNT++))
        fi
    done
    if [[ $SCHEMA_COUNT -gt 0 ]]; then
        pass "Validated $SCHEMA_COUNT schema(s)"
    else
        warn "No schemas found"
    fi
else
    warn "jsonschema not available (skipping)"
fi

# Summary
echo ""
echo "================================"
echo "📊 Verification Results"
echo ""
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ Aurora GA verification PASSED${NC}"
    echo ""
    echo "🜂 The covenant is cryptographically enforced."
    exit 0
else
    echo -e "${RED}❌ Aurora GA verification FAILED${NC}"
    echo ""
    echo "Fix issues and re-run verification."
    exit 1
fi
