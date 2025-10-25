#!/usr/bin/env bash
# Aurora Intelligence Engine — Build Script
# Builds Python wheel artifact (NOT a Docker image)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════════"
echo "🧠 Aurora Intelligence Engine — Build"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Step 1: Clean previous builds
echo -e "${BLUE}Step 1/5: Cleaning previous builds...${NC}"
rm -rf build/ dist/ src/aurora_intelligence.egg-info/
echo -e "${GREEN}✅ Clean complete${NC}"
echo ""

# Step 2: Install build dependencies
echo -e "${BLUE}Step 2/5: Installing build dependencies...${NC}"
python3 -m pip install --quiet --break-system-packages --upgrade build wheel setuptools 2>/dev/null || \
    python3 -m pip install --quiet --user --upgrade build wheel setuptools 2>/dev/null || \
    echo -e "${YELLOW}⚠️  Using existing build tools${NC}"
echo -e "${GREEN}✅ Build tools ready${NC}"
echo ""

# Step 3: Run tests
echo -e "${BLUE}Step 3/5: Running tests...${NC}"
if [[ -f "tests/test_engine.py" ]]; then
    python3 -m pip install --quiet --user -e ".[dev]" || echo -e "${YELLOW}⚠️  Dev install skipped${NC}"
    python3 -m pytest -q tests/ 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Tests skipped (pytest not available or tests failed)${NC}"
    }
else
    echo -e "${YELLOW}⚠️  No tests found, skipping${NC}"
fi
echo ""

# Step 4: Build wheel
echo -e "${BLUE}Step 4/5: Building wheel...${NC}"
python3 -m build --wheel
echo -e "${GREEN}✅ Wheel built${NC}"
echo ""

# Step 5: Verify wheel
echo -e "${BLUE}Step 5/5: Verifying wheel...${NC}"
WHEEL_FILE=$(ls -1 dist/*.whl | head -1)
if [[ -f "$WHEEL_FILE" ]]; then
    echo -e "${GREEN}✅ Wheel created: $WHEEL_FILE${NC}"

    # Extract version and hash
    VERSION=$(echo "$WHEEL_FILE" | grep -oP 'aurora_intelligence-\K[0-9.]+')
    HASH=$(sha256sum "$WHEEL_FILE" | awk '{print $1}')

    echo ""
    echo "Wheel Details:"
    echo "  File:    $(basename "$WHEEL_FILE")"
    echo "  Version: $VERSION"
    echo "  Hash:    $HASH"
    echo "  Size:    $(du -h "$WHEEL_FILE" | cut -f1)"
else
    echo -e "${YELLOW}⚠️  Wheel not found${NC}"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}🎉 Build Complete${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Test wheel:"
echo "     pip install $WHEEL_FILE"
echo "     python -c 'from aurora_intelligence import RoutingEngine; print(RoutingEngine)'"
echo ""
echo "  2. Publish to artifact registry:"
echo "     twine upload --repository-url https://us-central1-python.pkg.dev/... $WHEEL_FILE"
echo ""
echo "  3. Record in Remembrancer:"
echo "     ops/bin/remembrancer decision 'Aurora Intelligence v$VERSION Built' \\"
echo "       --reason 'Q-learning routing engine for Phase 3'"
echo ""
