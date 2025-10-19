#!/usr/bin/env bash
# spawn-repo.sh - VaultMesh Repository Generator
# Creates a new repository with all standard VaultMesh patterns

set -euo pipefail

REPO_NAME="${1:-}"
REPO_TYPE="${2:-service}"  # service, infra, tool

if [[ -z "$REPO_NAME" ]]; then
  cat <<'EOF'
Usage: spawn-repo.sh <name> [type]

Types:
  service   - Python/FastAPI microservice (default)
  infra     - Terraform infrastructure
  tool      - Bash/CLI tooling

Examples:
  spawn-repo.sh vaultmesh-core service
  spawn-repo.sh infra-monitoring infra
  spawn-repo.sh vm-cli tool
EOF
  exit 1
fi

REPO_DIR="/Users/sovereign/$REPO_NAME"

if [[ -d "$REPO_DIR" ]]; then
  echo "❌ Repository already exists: $REPO_DIR"
  exit 1
fi

echo "🧬 Spawning repository: $REPO_NAME (type: $REPO_TYPE)"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# ============================================================================
# Git initialization
# ============================================================================
git init
echo "✅ Git initialized"

# ============================================================================
# .gitignore
# ============================================================================
cat > .gitignore <<'GITIGNORE'
# Environment
.env
.env.local
*.env.backup

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
ENV/
env/
.venv

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
override.tf
override.tf.json

# Receipts & artifacts (keep structure, ignore content)
artifacts/*.json
receipts/*.json
logs/

# IDE
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Build artifacts
dist/
build/
*.egg-info/
GITIGNORE
echo "✅ .gitignore created"

# ============================================================================
# README.md
# ============================================================================
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
```
├── main.py              # FastAPI application
├── requirements.txt     # Python dependencies
├── Dockerfile           # Container definition
├── tests/               # Test suite
├── docs/                # Documentation
└── Makefile             # Build automation
```
STRUCT
    ;;
  infra)
    cat <<'STRUCT'
```
├── main.tf              # Terraform configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── providers.tf         # Provider config
├── scripts/             # Helper scripts
└── Makefile             # Terraform automation
```
STRUCT
    ;;
  tool)
    cat <<'STRUCT'
```
├── bin/                 # Executable scripts
├── lib/                 # Shared libraries
├── tests/               # BATS test suite
├── docs/                # Documentation
└── Makefile             # Build automation
```
STRUCT
    ;;
esac)

---

## 🧪 Testing

\`\`\`bash
make test               # Run full test suite
$(case "$REPO_TYPE" in
  service)
    echo "pytest tests/           # Run specific tests"
    ;;
  tool)
    echo "bats tests/             # Run specific tests"
    ;;
esac)
\`\`\`

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

# ============================================================================
# Makefile
# ============================================================================
case "$REPO_TYPE" in
  service)
    cat > Makefile <<'MAKEFILE'
.PHONY: help test ci dev clean lint format

help:
	@echo "Available commands:"
	@echo "  make test    - Run test suite"
	@echo "  make ci      - Full CI pipeline"
	@echo "  make dev     - Start development server"
	@echo "  make clean   - Clean artifacts"
	@echo "  make lint    - Run linters"
	@echo "  make format  - Format code"

test:
	@echo "🧪 Running tests..."
	@pytest -q || exit 1

ci: lint test
	@echo "✅ CI pipeline complete"

dev:
	@echo "🚀 Starting development server..."
	@uvicorn main:app --reload --host 0.0.0.0 --port 8000

clean:
	@echo "🧹 Cleaning artifacts..."
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .pytest_cache/

lint:
	@echo "🔍 Running linters..."
	@ruff check . || true
	@mypy . || true

format:
	@echo "✨ Formatting code..."
	@ruff format .
MAKEFILE
    ;;
  infra)
    cat > Makefile <<'MAKEFILE'
.PHONY: help init plan apply verify clean

help:
	@echo "Available commands:"
	@echo "  make init    - Initialize Terraform"
	@echo "  make plan    - Plan infrastructure changes"
	@echo "  make apply   - Apply infrastructure changes"
	@echo "  make verify  - Verify deployment"
	@echo "  make clean   - Clean Terraform cache"

init:
	@echo "🚀 Initializing Terraform..."
	@terraform init

plan:
	@echo "📋 Planning infrastructure changes..."
	@. .env && terraform plan

apply:
	@echo "⚡ Applying infrastructure changes..."
	@. .env && terraform apply

verify:
	@echo "🔍 Verifying deployment..."
	@terraform validate

clean:
	@echo "🧹 Cleaning Terraform cache..."
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
MAKEFILE
    ;;
  tool)
    cat > Makefile <<'MAKEFILE'
.PHONY: help test ci clean lint format install

help:
	@echo "Available commands:"
	@echo "  make test    - Run test suite (BATS)"
	@echo "  make ci      - Full CI pipeline"
	@echo "  make clean   - Clean artifacts"
	@echo "  make lint    - Run shellcheck"
	@echo "  make format  - Format shell scripts"
	@echo "  make install - Install CLI to ~/.local/bin"

test:
	@echo "🧪 Running tests..."
	@bats -r tests/

ci: lint test
	@echo "✅ CI pipeline complete"

clean:
	@echo "🧹 Cleaning artifacts..."
	@rm -rf logs/ artifacts/

lint:
	@echo "🔍 Running shellcheck..."
	@shellcheck -x bin/* lib/*.sh

format:
	@echo "✨ Formatting code..."
	@shfmt -w -s -i 2 bin/ lib/

install:
	@echo "📦 Installing CLI..."
	@mkdir -p ~/.local/bin
	@cp bin/* ~/.local/bin/
	@echo "✅ Installed to ~/.local/bin (ensure it's in your PATH)"
MAKEFILE
    ;;
esac
echo "✅ Makefile created"

# ============================================================================
# SECURITY.md
# ============================================================================
cat > SECURITY.md <<'SECURITY'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

**DO NOT** open a public issue for security vulnerabilities.

Instead, please report security issues via:
- Email: security@vaultmesh.org
- GitHub Security Advisories (preferred)

### Response SLOs

- **Acknowledgment:** Within 48 hours
- **Initial Assessment:** Within 7 days
- **Fix Timeline:** Depends on severity
  - Critical: 1-7 days
  - High: 7-30 days
  - Medium/Low: Next release cycle

## Security Practices

- All secrets must be in `.env` files (never committed)
- Cryptographic operations use industry-standard libraries
- Receipt generation for audit trails
- Regular dependency updates
- Automated security scanning in CI/CD

## Disclosure Policy

We follow responsible disclosure:
1. Private notification to maintainers
2. Assessment and fix development
3. Coordinated public disclosure
4. CVE assignment (if applicable)
SECURITY

echo "✅ SECURITY.md created"

# ============================================================================
# LICENSE
# ============================================================================
cat > LICENSE <<'LICENSE'
MIT License

Copyright (c) 2025 VaultMesh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE
echo "✅ LICENSE created"

# ============================================================================
# AGENTS.md
# ============================================================================
cat > AGENTS.md <<AGENTS
# Repository Guidelines

## Build, Test, and Development Commands

$(case "$REPO_TYPE" in
  service)
    echo "- \`make dev\` — Start development server"
    echo "- \`make test\` — Run pytest suite"
    echo "- \`make ci\` — Full CI pipeline (lint + test)"
    echo "- \`make lint\` — Run ruff and mypy"
    echo "- \`make format\` — Auto-format with ruff"
    ;;
  infra)
    echo "- \`make init\` — Initialize Terraform"
    echo "- \`make plan\` — Plan infrastructure changes"
    echo "- \`make apply\` — Apply changes"
    echo "- \`make verify\` — Validate configuration"
    ;;
  tool)
    echo "- \`make test\` — Run BATS test suite"
    echo "- \`make ci\` — Full CI pipeline (lint + test)"
    echo "- \`make lint\` — Run shellcheck"
    echo "- \`make format\` — Auto-format with shfmt"
    echo "- \`make install\` — Install to ~/.local/bin"
    ;;
esac)

## Code Style

$(case "$REPO_TYPE" in
  service)
    cat <<'STYLE'
**Python:**
- Use type hints
- FastAPI for services
- 4-space indentation
- Follow PEP 8
- Ruff for linting and formatting
STYLE
    ;;
  infra)
    cat <<'STYLE'
**Terraform:**
- Use \`terraform fmt\`
- All values in variables (no hardcoding)
- Secrets in \`.env\` files (gitignored)
- Descriptive resource names
STYLE
    ;;
  tool)
    cat <<'STYLE'
**Bash:**
- 2-space indentation (\`shfmt -w -s -i 2\`)
- ShellCheck compliant
- Use \`set -euo pipefail\`
- Quote variables
- Prefer \`[[  ]]\` over \`[  ]\`
STYLE
    ;;
esac)

## Testing Guidelines

$(case "$REPO_TYPE" in
  service)
    echo "- Place tests in \`tests/\` directory"
    echo "- Use pytest fixtures for setup/teardown"
    echo "- Mock external dependencies"
    echo "- Aim for >80% coverage"
    ;;
  infra)
    echo "- Validate all Terraform configs"
    echo "- Test with \`terraform plan\` before apply"
    echo "- Document manual verification steps"
    ;;
  tool)
    echo "- Use BATS for shell script testing"
    echo "- Place tests in \`tests/\` directory"
    echo "- Test both success and failure cases"
    echo "- Verify output format and exit codes"
    ;;
esac)

## Security

- Never commit secrets (use \`.env\`)
- Generate receipts for audit trails
- Follow principle of least privilege
- See [SECURITY.md](SECURITY.md) for vulnerability reporting

## Commit Guidelines

- Use conventional commits: \`feat:\`, \`fix:\`, \`docs:\`, \`refactor:\`
- Keep commits focused and atomic
- Reference issues in commit messages
- Sign commits (GPG) when possible

---

**See also:** [Master AGENTS.md](/Users/sovereign/md_docs_collect_20251017_153711/files/Users/sovereign/MASTER_AGENTS.md) for ecosystem-wide guidelines
AGENTS
echo "✅ AGENTS.md created"

# ============================================================================
# Type-specific files
# ============================================================================
case "$REPO_TYPE" in
  service)
    # requirements.txt
    cat > requirements.txt <<'REQUIREMENTS'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
pydantic>=2.5.0
pytest>=7.4.0
pytest-cov>=4.1.0
ruff>=0.1.0
mypy>=1.7.0
REQUIREMENTS
    echo "✅ requirements.txt created"

    # main.py
    cat > main.py <<'MAIN'
from fastapi import FastAPI

app = FastAPI(title="$REPO_NAME")

@app.get("/")
def read_root():
    return {"status": "ok", "service": "$REPO_NAME"}

@app.get("/health")
def health_check():
    return {"healthy": True}
MAIN
    echo "✅ main.py created"

    # tests/
    mkdir -p tests
    cat > tests/test_main.py <<'TEST'
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "status" in response.json()

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["healthy"] is True
TEST
    echo "✅ tests/ created"
    ;;

  infra)
    # Terraform files
    cat > main.tf <<'MAIN_TF'
# Main infrastructure configuration
MAIN_TF

    cat > variables.tf <<'VARS'
# Input variables
VARS

    cat > outputs.tf <<'OUTPUTS'
# Output values
OUTPUTS

    cat > providers.tf <<'PROVIDERS'
# Provider configuration
terraform {
  required_version = ">= 1.6.0"
}
PROVIDERS

    cat > .env.example <<'ENV'
# Copy to .env and fill in values
# TF_VAR_example_var=value
ENV
    echo "✅ Terraform files created"
    ;;

  tool)
    # bin/ and lib/
    mkdir -p bin lib tests
    cat > bin/example <<'BIN'
#!/usr/bin/env bash
set -euo pipefail
echo "Example CLI tool"
BIN
    chmod +x bin/example

    cat > lib/common.sh <<'LIB'
#!/usr/bin/env bash
# Common library functions

log_info() {
  echo "[INFO] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}
LIB

    cat > tests/example.bats <<'BATS'
#!/usr/bin/env bats

@test "example command runs" {
  run bin/example
  [ "$status" -eq 0 ]
}
BATS
    echo "✅ bin/, lib/, tests/ created"
    ;;
esac

# ============================================================================
# .env.example
# ============================================================================
cat > .env.example <<'ENV_EXAMPLE'
# Copy to .env and fill in actual values
# Never commit .env to Git
ENV_EXAMPLE
echo "✅ .env.example created"

# ============================================================================
# docs/
# ============================================================================
mkdir -p docs
cat > docs/README.md <<'DOCS'
# Documentation

Add extended documentation here.
DOCS
echo "✅ docs/ directory created"

# ============================================================================
# Initial Git commit
# ============================================================================
git add .
git commit -m "feat: initial repository scaffold

Generated using VaultMesh spawn-repo.sh template
Type: $REPO_TYPE"
echo "✅ Initial commit created"

# ============================================================================
# Summary
# ============================================================================
cat <<SUMMARY

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Repository spawned successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Location: $REPO_DIR
🔧 Type: $REPO_TYPE

Next steps:
1. cd $REPO_DIR
2. Edit README.md with actual description
3. Configure .env (copy from .env.example)
$(case "$REPO_TYPE" in
  service)
    echo "4. python -m venv venv && source venv/bin/activate"
    echo "5. pip install -r requirements.txt"
    ;;
  infra)
    echo "4. Configure providers.tf and variables.tf"
    echo "5. make init"
    ;;
  tool)
    echo "4. Implement your CLI in bin/"
    echo "5. Add tests in tests/"
    ;;
esac)
6. make test
7. Create GitHub repository and push

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY
