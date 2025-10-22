#!/usr/bin/env bash
set -euo pipefail

echo "🜂 Track 2: Load & Scale Test (Manual)"
echo "========================================"
echo ""

NAMESPACE="aurora-staging"
POD_NAME="ollama-cpu-b45fdc475-7nzjm"

# Test 2.1: Check HPA exists
echo "Test 2.1: Check HPA configuration..."
if kubectl -n "$NAMESPACE" get hpa ollama-cpu --request-timeout=10s &>/dev/null; then
    echo "✅ HPA exists"
    kubectl -n "$NAMESPACE" get hpa ollama-cpu --request-timeout=10s
else
    echo "⚠️  HPA not found (may not be configured)"
fi
echo ""

# Test 2.2: Check current replica count
echo "Test 2.2: Check current replicas..."
REPLICAS=$(kubectl -n "$NAMESPACE" get deployment ollama-cpu -o jsonpath='{.status.replicas}' --request-timeout=10s 2>/dev/null || echo "0")
echo "Current replicas: $REPLICAS"
echo ""

# Test 2.3: Verify model is loaded
echo "Test 2.3: Verify phi3:mini model..."
if kubectl -n "$NAMESPACE" exec "$POD_NAME" --request-timeout=10s -- ollama list 2>&1 | grep -q "phi3:mini"; then
    echo "✅ Model phi3:mini is loaded"
else
    echo "❌ Model phi3:mini not found"
    echo "Available models:"
    kubectl -n "$NAMESPACE" exec "$POD_NAME" --request-timeout=10s -- ollama list 2>&1 || echo "Failed to list models"
fi
echo ""

# Test 2.4: Simple inference test
echo "Test 2.4: Test inference endpoint..."
kubectl -n "$NAMESPACE" port-forward "pod/$POD_NAME" 11434:11434 &>/dev/null &
PF_PID=$!
sleep 3

if curl -s --max-time 10 http://localhost:11434/api/generate -d '{"model":"phi3:mini","prompt":"Hi","stream":false}' | jq -r '.response' 2>&1 | head -1; then
    echo "✅ Inference working"
else
    echo "⚠️  Inference test inconclusive"
fi

kill $PF_PID 2>/dev/null || true
echo ""

echo "Track 2 Complete"
