#!/usr/bin/env bash
# source.sh - Generate main application source code
# Usage: source.sh <repo-name> <repo-type>

set -euo pipefail

REPO_NAME="${1:-myapp}"
REPO_TYPE="${2:-service}"

case "$REPO_TYPE" in
  service)
    # requirements.txt
    cat > requirements.txt <<'REQUIREMENTS'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
pydantic>=2.5.0
httpx>=0.25.0
pytest>=7.4.0
pytest-cov>=4.1.0
ruff>=0.1.0
mypy>=1.7.0
REQUIREMENTS
    echo "✅ requirements.txt created"

    # main.py
    cat > main.py <<MAIN
from fastapi import FastAPI

app = FastAPI(title="${REPO_NAME}")

@app.get("/")
def read_root():
    return {"status": "ok", "service": "${REPO_NAME}"}

@app.get("/health")
def health_check():
    return {"healthy": True}
MAIN
    echo "✅ main.py created"
    ;;

  infra)
    # Terraform main
    cat > main.tf <<'TF'
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
TF
    echo "✅ main.tf created"
    
    cat > variables.tf <<'VARS'
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
VARS
    echo "✅ variables.tf created"
    ;;

  tool)
    # Main CLI script
    mkdir -p bin
    cat > bin/main <<'TOOL'
#!/usr/bin/env bash
set -euo pipefail

# Main CLI entry point
echo "TODO: Implement CLI logic"
TOOL
    chmod +x bin/main
    echo "✅ bin/main created"
    ;;

  *)
    echo "❌ Unknown repo type: $REPO_TYPE"
    exit 1
    ;;
esac

