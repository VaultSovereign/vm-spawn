#!/bin/bash
# Smoke test for dual-backend PSI agents

set -e

echo "🧪 Testing Kalman backend (port 8001)..."
curl -sf http://localhost:8001/health | jq -e '.status == "healthy"' > /dev/null
curl -sf http://localhost:8001/step -H 'content-type: application/json' \
  -d '{"x":[0.1,0.2,0.3,0.4,0.0,-0.1,0.05,0.2,0.1,0.0,0.05,-0.05,0.12,0.0,0.03,0.02], "apply_guardian": true}' \
  | jq -e '.Psi' > /dev/null
curl -sf http://localhost:8001/guardian/statistics | jq -e '.kind' > /dev/null
echo "✅ Kalman backend OK"

echo "🧪 Testing Seasonal backend (port 8002)..."
curl -sf http://localhost:8002/health | jq -e '.status == "healthy"' > /dev/null
curl -sf http://localhost:8002/step -H 'content-type: application/json' \
  -d '{"x":[0.1,0.2,0.3,0.4,0.0,-0.1,0.05,0.2,0.1,0.0,0.05,-0.05,0.12,0.0,0.03,0.02], "apply_guardian": true}' \
  | jq -e '.Psi' > /dev/null
curl -sf http://localhost:8002/guardian/statistics | jq -e '.kind' > /dev/null
echo "✅ Seasonal backend OK"

echo ""
echo "🎉 Both backends operational!"
echo "   Kalman:   http://localhost:8001"
echo "   Seasonal: http://localhost:8002"
echo "   RabbitMQ: http://localhost:15672 (guest/guest)"
