#!/usr/bin/env bash
# cicd.sh - Generate GitHub Actions CI/CD pipeline
# Usage: cicd.sh <repo-name>

set -euo pipefail

REPO_NAME="${1:-myapp}"

mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'CI'
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: make test
      
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          
  docker:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: docker/build-push-action@v4
        with:
          context: .
          push: false
          tags: ${{ github.repository }}:latest
CI

echo "✅ GitHub Actions CI/CD"

