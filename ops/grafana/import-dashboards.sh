#!/bin/bash
# Automated Grafana Dashboard Import via API
# Usage: ./import-dashboards.sh [grafana-url] [admin-password]

set -euo pipefail

GRAFANA_URL="${1:-http://localhost:3000}"
GRAFANA_PASSWORD="${2:-}"
DASHBOARD_DIR="$(cd "$(dirname "$0")/dashboards" && pwd)"

# Get password from K8s secret if not provided
if [ -z "$GRAFANA_PASSWORD" ]; then
  echo "Fetching Grafana password from K8s secret..."
  GRAFANA_PASSWORD=$(kubectl -n aurora-staging get secret grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "admin")
fi

echo "🜂 Importing VaultMesh dashboards to Grafana..."
echo "URL: $GRAFANA_URL"
echo "Dashboards: $DASHBOARD_DIR"

# Import each dashboard
for dashboard_file in "$DASHBOARD_DIR"/*.json; do
  dashboard_name=$(basename "$dashboard_file")
  echo "Importing: $dashboard_name"
  
  # Wrap dashboard JSON in Grafana import format
  payload=$(jq -n --slurpfile dashboard "$dashboard_file" '{
    dashboard: $dashboard[0],
    overwrite: true,
    inputs: [],
    folderId: 0
  }')
  
  # Import via API
  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "admin:$GRAFANA_PASSWORD" \
    -d "$payload" \
    "$GRAFANA_URL/api/dashboards/db")
  
  # Check result
  if echo "$response" | jq -e '.status == "success"' > /dev/null 2>&1; then
    uid=$(echo "$response" | jq -r '.uid')
    echo "✅ Imported: $dashboard_name (uid: $uid)"
  else
    echo "❌ Failed: $dashboard_name"
    echo "$response" | jq '.'
  fi
done

echo ""
echo "🎉 Dashboard import complete!"
echo "View dashboards: $GRAFANA_URL/dashboards"
