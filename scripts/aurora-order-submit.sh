#!/usr/bin/env bash
set -euo pipefail
: "${AURORA_BRIDGE_URL:=http://localhost:8080}"
ORDER_JSON="${1:-tmp/order.json}"
KEY="${2:-secrets/vm_httpsig.key}"
CANON=$(jq -cS . "$ORDER_JSON")
SIG=$(printf "%s" "$CANON" | openssl pkeyutl -sign -inkey "$KEY" | openssl base64 -A)
jq --arg s "$SIG" '.signature=$s' "$ORDER_JSON" > "${ORDER_JSON%.json}.signed.json"
curl -sS -X POST "$AURORA_BRIDGE_URL/aurora/order" -H 'Content-Type: application/json' --data-binary @"${ORDER_JSON%.json}.signed.json"
