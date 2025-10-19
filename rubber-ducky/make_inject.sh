#!/usr/bin/env bash
set -euo pipefail
encoder="${1:-DuckEncoder.jar}"
payload="${2:-payload-windows-github.v2.3.0.txt}"
out="${3:-inject.bin}"
if [[ ! -f "$encoder" ]]; then
  echo "Encoder $encoder not found. Place DuckEncoder.jar next to this script or pass a path."
  exit 2
fi
java -jar "$encoder" -i "$payload" -o "$out" -l EN
echo "Wrote $out"
