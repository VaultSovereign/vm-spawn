#!/usr/bin/env bash
set -euo pipefail

echo "🜂 Track 2: Load & Scale Test"
echo "=============================="
echo ""

NAMESPACE="aurora-staging"
POD_NAME="ollama-cpu-b45fdc475-7nzjm"
RESULTS_DIR="test-results/track2"
mkdir -p "$RESULTS_DIR"

# Test 2.1: HPA configuration
echo "Test 2.1: HPA configuration..."
if kubectl -n "$NAMESPACE" get hpa ollama-cpu --request-timeout=10s &>"$RESULTS_DIR/hpa-initial.log"; then
    echo "✅ HPA configured"
    cat "$RESULTS_DIR/hpa-initial.log"
else
    echo "⚠️  HPA not found"
fi
echo ""

# Test 2.2: Initial replica count
echo "Test 2.2: Initial replica count..."
INITIAL_REPLICAS=$(kubectl -n "$NAMESPACE" get deployment ollama-cpu -o jsonpath='{.status.replicas}' --request-timeout=10s 2>/dev/null || echo "1")
echo "Initial replicas: $INITIAL_REPLICAS" | tee "$RESULTS_DIR/replicas-initial.log"
echo ""

# Test 2.3: Model availability
echo "Test 2.3: Model availability..."
kubectl -n "$NAMESPACE" exec "$POD_NAME" --request-timeout=10s -- ollama list 2>&1 | tee "$RESULTS_DIR/model-list.log"
if grep -q "phi3:mini" "$RESULTS_DIR/model-list.log"; then
    echo "✅ phi3:mini loaded"
else
    echo "❌ phi3:mini not found"
    exit 1
fi
echo ""

# Test 2.4: Load test with curl
echo "Test 2.4: Load test (10 requests)..."
kubectl -n "$NAMESPACE" port-forward "pod/$POD_NAME" 11434:11434 &>/dev/null &
PF_PID=$!
sleep 3

SUCCESS=0
FAIL=0
for i in {1..10}; do
    if curl -s --max-time 15 http://localhost:11434/api/generate \
        -d '{"model":"phi3:mini","prompt":"Test","stream":false}' \
        | jq -r '.response' &>/dev/null; then
        SUCCESS=$((SUCCESS + 1))
        echo -n "."
    else
        FAIL=$((FAIL + 1))
        echo -n "x"
    fi
done
echo ""
echo "Results: $SUCCESS success, $FAIL failed" | tee "$RESULTS_DIR/load-test.log"

kill $PF_PID 2>/dev/null || true
echo ""

# Test 2.5: Final replica count
echo "Test 2.5: Final replica count..."
sleep 5
FINAL_REPLICAS=$(kubectl -n "$NAMESPACE" get deployment ollama-cpu -o jsonpath='{.status.replicas}' --request-timeout=10s 2>/dev/null || echo "1")
echo "Final replicas: $FINAL_REPLICAS" | tee "$RESULTS_DIR/replicas-final.log"
echo ""

# Summary
echo "Track 2 Summary:"
echo "  Initial replicas: $INITIAL_REPLICAS"
echo "  Final replicas: $FINAL_REPLICAS"
echo "  Load test: $SUCCESS/$((SUCCESS + FAIL)) successful"
echo ""

if [ "$SUCCESS" -ge 8 ]; then
    echo "✅ Track 2 PASS"
    echo "PASS" > "$RESULTS_DIR/summary.result"
    exit 0
else
    echo "❌ Track 2 FAIL"
    echo "FAIL" > "$RESULTS_DIR/summary.result"
    exit 1
fi
