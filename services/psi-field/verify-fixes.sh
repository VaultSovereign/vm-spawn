#!/bin/bash
# Verify all audit fixes are in place

set -e

echo "🔍 Verifying PSI-Field audit fixes..."
echo ""

# Check files exist
echo "📁 Checking files..."
files=(
    "src/main.py"
    "tests/test_backend_switch.py"
    "tests/test_guardian_advanced.py"
    "tests/test_mq_degrades_cleanly.py"
    "docker-compose.psiboth.yml"
    "k8s/psi-both.yaml"
    "smoke-test-dual.sh"
    "DUAL_BACKEND_GUIDE.md"
    "AUDIT_FIXES_SUMMARY.md"
    "QUICKREF.md"
)

for f in "${files[@]}"; do
    if [ -f "$f" ]; then
        echo "  ✅ $f"
    else
        echo "  ❌ $f MISSING"
        exit 1
    fi
done

echo ""
echo "🔧 Checking main.py fixes..."

# Check for PSI_BACKEND env var
if grep -q 'PSI_BACKEND = os.environ.get("PSI_BACKEND"' src/main.py; then
    echo "  ✅ PSI_BACKEND env var added"
else
    echo "  ❌ PSI_BACKEND env var missing"
    exit 1
fi

# Check for AdvancedGuardian import
if grep -q 'from .guardian_advanced import AdvancedGuardian' src/main.py; then
    echo "  ✅ AdvancedGuardian import added"
else
    echo "  ❌ AdvancedGuardian import missing"
    exit 1
fi

# Check for /guardian/statistics endpoint
if grep -q '@app.get("/guardian/statistics"' src/main.py; then
    echo "  ✅ /guardian/statistics endpoint added"
else
    echo "  ❌ /guardian/statistics endpoint missing"
    exit 1
fi

# Check for duplicate startup (should only be one)
startup_count=$(grep -c '@app.on_event("startup")' src/main.py || true)
if [ "$startup_count" -eq 1 ]; then
    echo "  ✅ Single startup handler (no duplicates)"
else
    echo "  ❌ Found $startup_count startup handlers (expected 1)"
    exit 1
fi

echo ""
echo "🧪 Checking syntax..."
python3 -m py_compile src/main.py
echo "  ✅ Python syntax valid"

echo ""
echo "🎉 All audit fixes verified!"
echo ""
echo "Next steps:"
echo "  1. Run tests: pytest -q"
echo "  2. Commit: ./commit-fixes.sh"
echo "  3. Deploy: docker compose -f docker-compose.psiboth.yml up -d --build"
echo "  4. Smoke test: ./smoke-test-dual.sh"
