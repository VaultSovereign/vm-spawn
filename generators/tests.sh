#!/usr/bin/env bash
# tests.sh - Generate test suite
# Usage: tests.sh

set -euo pipefail

# Create tests directory
mkdir -p tests

# Generate test_main.py
cat > tests/test_main.py <<'TEST'
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["healthy"] is True
TEST

echo "✅ tests/ created"

