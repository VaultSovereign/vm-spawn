#!/usr/bin/env bash
# readme.sh - Generate README.md
# Usage: readme.sh <repo-name> <repo-type>

set -euo pipefail

REPO_NAME="${1:-myapp}"
REPO_TYPE="${2:-service}"

cat > README.md <<README
# $REPO_NAME

**VaultMesh ${REPO_TYPE} - [One-line description]**

---

## 🎯 Overview

[Describe what this repository does]

**Forge Law:**
- UI is theatre
- Code is truth
- If it's not in Git, it doesn't exist

---

## 📋 Prerequisites

$(case "$REPO_TYPE" in
  service)
    echo "- Python >= 3.11"
    echo "- Docker (optional, for containerized deployment)"
    ;;
  infra)
    echo "- Terraform >= 1.6.0"
    echo "- Cloud provider CLI (AWS/GCP/Cloudflare)"
    ;;
  tool)
    echo "- Bash >= 4.0"
    echo "- jq, shellcheck (for development)"
    ;;
esac)

---

## 🚀 Quick Start

\`\`\`bash
# Clone repository
git clone https://github.com/VaultMesh/$REPO_NAME
cd $REPO_NAME

$(case "$REPO_TYPE" in
  service)
    echo "# Install dependencies"
    echo "python -m venv venv"
    echo "source venv/bin/activate"
    echo "pip install -r requirements.txt"
    echo ""
    echo "# Run tests"
    echo "make test"
    echo ""
    echo "# Start service"
    echo "make dev"
    ;;
  infra)
    echo "# Initialize Terraform"
    echo "make init"
    echo ""
    echo "# Plan changes"
    echo "make plan"
    echo ""
    echo "# Apply infrastructure"
    echo "make apply"
    ;;
  tool)
    echo "# Run tests"
    echo "make test"
    echo ""
    echo "# Install CLI"
    echo "make install"
    ;;
esac)
\`\`\`

---

## 📦 Repository Structure

$(case "$REPO_TYPE" in
  service)
    cat <<'STRUCT'
\`\`\`
├── main.py              # FastAPI application
├── requirements.txt     # Python dependencies
├── Dockerfile           # Container definition
├── tests/               # Test suite
├── docs/                # Documentation
└── Makefile             # Build automation
\`\`\`
STRUCT
    ;;
  infra)
    cat <<'STRUCT'
\`\`\`
├── main.tf              # Terraform configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── docs/                # Documentation
└── Makefile             # Build automation
\`\`\`
STRUCT
    ;;
  tool)
    cat <<'STRUCT'
\`\`\`
├── bin/                 # Executable scripts
├── lib/                 # Shared libraries
├── tests/               # BATS test suite
├── docs/                # Documentation
└── Makefile             # Build automation
\`\`\`
STRUCT
    ;;
esac)

---

## 🔒 Security

See [SECURITY.md](SECURITY.md) for security policy and vulnerability reporting.

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

**Generated:** $(date -u +%Y-%m-%d)  
**VaultMesh Ecosystem** | Self-verifying • Self-auditing • Self-attesting
README

echo "✅ README.md created"

