#!/usr/bin/env bash
set -euo pipefail

echo "🜂 Aurora End-to-End Smoke Test"
echo "================================"
echo

# 0) Preflight checks
echo ">>> Preflight: checking dependencies..."
command -v jq >/dev/null || { echo "❌ jq required (install: apt install jq)"; exit 1; }
command -v openssl >/dev/null || { echo "❌ openssl required"; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 required"; exit 1; }
command -v curl >/dev/null || { echo "❌ curl required"; exit 1; }
echo "✅ All dependencies present"
echo

# 1) Generate dev keys if needed
echo ">>> Step 1: Generating ED25519 keys (if needed)..."
mkdir -p secrets
if [ ! -f secrets/vm_httpsig.key ]; then
  openssl genpkey -algorithm ED25519 -out secrets/vm_httpsig.key
  openssl pkey -in secrets/vm_httpsig.key -pubout -out secrets/vm_httpsig.pub
  echo "✅ Generated new ED25519 keypair"
else
  echo "✅ Using existing keypair"
fi
echo

# 2) Start mock bridge + metrics exporters
echo ">>> Step 2: Starting background services..."
pkill -f aurora-axelar-mock.py 2>/dev/null || true
pkill -f aurora-metrics-exporter.py 2>/dev/null || true
pkill -f sim-metrics-exporter.py 2>/dev/null || true

AURORA_ORDER_SCHEMA="schemas/axelar-order.schema.json" \
AURORA_PUBKEY="secrets/vm_httpsig.pub" \
python3 scripts/aurora-axelar-mock.py >/tmp/aurora-mock.log 2>&1 &
MOCK_PID=$!

python3 scripts/aurora-metrics-exporter.py >/tmp/aurora-metrics.log 2>&1 &
METRICS_PID=$!

echo "✅ Aurora mock bridge started (PID: $MOCK_PID)"
echo "✅ Aurora metrics exporter started (PID: $METRICS_PID)"
sleep 2
echo

# 3) Generate test order
echo ">>> Step 3: Generating test order..."
mkdir -p tmp
cat > tmp/order.json <<'JSON'
{
  "treaty_id": "AURORA-AKASH-001",
  "tenant_id": "tenant-42",
  "region": "eu-west-1",
  "gpu_hours": 50,
  "nonce": "smoke-test-001",
  "deadline_utc": "2030-01-01T00:00:00Z",
  "callback_url": "https://example.com/callback"
}
JSON
echo "✅ Test order created"
echo

# 4) Submit order (sign + POST)
echo ">>> Step 4: Submitting signed order to bridge..."
if AURORA_BRIDGE_URL="http://localhost:8080" bash scripts/aurora-order-submit.sh tmp/order.json > /tmp/aurora-ack.json 2>&1; then
  echo "✅ Order submitted successfully"
  cat /tmp/aurora-ack.json | jq '.'

  # Validate ACK format
  if jq -e '.ack_id|test("^AKASH-JOB-[0-9]{4,}$")' /tmp/aurora-ack.json >/dev/null 2>&1; then
    echo "✅ ACK format validated"
  else
    echo "⚠️  ACK format unexpected but continuing..."
  fi
else
  echo "⚠️  Order submission had issues (check /tmp/aurora-ack.json)"
fi
echo

# 5) Run simulator to generate KPIs
echo ">>> Step 5: Running multi-provider routing simulator..."
if SEED=42 STEPS=60 make sim-run >/tmp/sim-run.log 2>&1; then
  echo "✅ Simulator completed (60 steps, seed=42)"

  # Show summary
  if [ -f sim/multi-provider-routing-simulator/out/step_metrics.csv ]; then
    echo "📊 Final step metrics:"
    tail -1 sim/multi-provider-routing-simulator/out/step_metrics.csv
  fi
else
  echo "❌ Simulator failed (check /tmp/sim-run.log)"
  exit 1
fi
echo

# 6) Start simulator metrics exporter
echo ">>> Step 6: Starting simulator metrics exporter..."
python3 scripts/sim-metrics-exporter.py >/tmp/sim-metrics.log 2>&1 &
SIM_METRICS_PID=$!
echo "✅ Simulator metrics exporter started (PID: $SIM_METRICS_PID)"
sleep 2
echo

# 7) Verify Prometheus endpoints
echo ">>> Step 7: Verifying Prometheus endpoints..."
echo "--- Aurora metrics (port 9109) ---"
if curl -sf http://localhost:9109/metrics | head -20; then
  echo
  echo "✅ Aurora metrics endpoint responsive"
else
  echo "❌ Aurora metrics endpoint failed"
fi
echo

echo "--- Simulator metrics (port 9110) ---"
if curl -sf http://localhost:9110/metrics | head -15; then
  echo
  echo "✅ Simulator metrics endpoint responsive"
else
  echo "⚠️  Simulator metrics endpoint not responding"
fi
echo

# 8) Test receipt generation (if artifacts exist)
echo ">>> Step 8: Testing receipt generation..."
mkdir -p /tmp/test-artifacts
echo "test-data-$(date +%s)" > /tmp/test-artifacts/test.txt
echo '{"meta":"test"}' > /tmp/test-artifacts/meta.json

if bash scripts/aurora-receipt-verify.sh /tmp/test-artifacts /tmp/test-receipt.json 2>&1 | tail -5; then
  if [ -f /tmp/test-receipt.json ]; then
    echo "✅ Receipt generated"
    jq '.' /tmp/test-receipt.json
  fi
else
  echo "⚠️  Receipt generation had issues (may need TSA access)"
fi
echo

# 9) Summary
echo "================================"
echo "🜂 Smoke Test Complete"
echo "================================"
echo
echo "Services running:"
echo "  - Aurora mock bridge:    http://localhost:8080"
echo "  - Aurora metrics:        http://localhost:9109/metrics"
echo "  - Simulator metrics:     http://localhost:9110/metrics"
echo
echo "Logs:"
echo "  - Mock bridge:     /tmp/aurora-mock.log"
echo "  - Metrics:         /tmp/aurora-metrics.log"
echo "  - Simulator:       /tmp/sim-run.log"
echo "  - Sim metrics:     /tmp/sim-metrics.log"
echo
echo "Artifacts:"
echo "  - ACK response:    /tmp/aurora-ack.json"
echo "  - Receipt:         /tmp/test-receipt.json"
echo "  - Simulator CSVs:  sim/multi-provider-routing-simulator/out/"
echo
echo "To stop services:"
echo "  kill $MOCK_PID $METRICS_PID $SIM_METRICS_PID"
echo
echo "Next: Review metrics, check alerts, run 'make sim-run' for different scenarios"
echo
