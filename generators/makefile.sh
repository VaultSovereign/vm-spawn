#!/usr/bin/env bash
# makefile.sh - Generate Makefile
# Usage: makefile.sh

set -euo pipefail

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
	@if [ -d ".venv" ]; then \
		PYTHONPATH=. .venv/bin/pytest -q || exit 1; \
	else \
		PYTHONPATH=. pytest -q || exit 1; \
	fi

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

echo "✅ Makefile created"

