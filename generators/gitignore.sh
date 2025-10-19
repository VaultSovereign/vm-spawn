#!/usr/bin/env bash
# gitignore.sh - Generate .gitignore file
# Usage: gitignore.sh

set -euo pipefail

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

