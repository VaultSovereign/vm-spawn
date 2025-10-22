#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="${1:-/var/log/vm-spawn-job}"
OUT_JSON="${2:-/tmp/receipt.json}"
TIMESTAMP_AUTHORITY="${TSA_URL:-https://freetsa.org/tsr}"

# 1) Tar and hash files
tar czf /tmp/job-artifacts.tgz -C "$ARTIFACT_DIR" .
sha256sum /tmp/job-artifacts.tgz | awk '{print $1}' > /tmp/job-artifacts.tgz.sha256

# 2) Build simple Merkle (file hash + tar hash)
FILE_HASH=$(cat /tmp/job-artifacts.tgz.sha256)
META=$(printf '{"ts":"%s","size":%s}\n' "$(date -u +%FT%TZ)" "$(stat -c%s /tmp/job-artifacts.tgz)")
META_HASH=$(printf "%s" "$META" | sha256sum | awk '{print $1}')
ROOT=$(printf "%s%s" "$FILE_HASH" "$META_HASH" | sha256sum | awk '{print $1}')

# 3) RFC3161 timestamp (DER)
openssl ts -query -data <(echo -n "$ROOT") -sha256 -cert -no_nonce -out /tmp/timestamp.tsq
curl -sS -H 'Content-Type: application/timestamp-query' --data-binary @/tmp/timestamp.tsq "$TIMESTAMP_AUTHORITY" -o /tmp/timestamp.tsr

# 4) Pin to IPFS (requires ipfs cli or HTTP API; fallback: just emit paths)
if command -v ipfs >/dev/null 2>&1; then
  CID_TGZ=$(ipfs add -Q /tmp/job-artifacts.tgz)
  CID_TSR=$(ipfs add -Q /tmp/timestamp.tsr)
else
  CID_TGZ="ipfs-not-installed"
  CID_TSR="ipfs-not-installed"
fi

# 5) Emit receipt JSON
jq -n --arg root "$ROOT" --arg cid_tgz "$CID_TGZ" --arg cid_tsr "$CID_TSR" \
  --arg meta "$META" '{
  "merkle_root": $root,
  "artifacts_cid": $cid_tgz,
  "timestamp_cid": $cid_tsr,
  "meta": ($meta|fromjson)
}' > "$OUT_JSON"

echo "[ok] receipt at $OUT_JSON"
