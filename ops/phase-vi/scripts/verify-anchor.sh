#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI="$ROOT_DIR/../../vm"
RECEIPTS_DIR="$ROOT_DIR/../receipts"
FORMAT="json"
PROFILE="${VAULTMESH_PROFILE:-default}"

usage() {
  cat <<USAGE
verify-anchor.sh - Validate the latest VaultMesh anchor receipts

Usage: verify-anchor.sh [--profile PROFILE] [--format json|table]

Options:
  --profile PROFILE    VaultMesh profile (defaults to $PROFILE)
  --format FORMAT      Output format for vm audit verify (default: json)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -x "$CLI" ]]; then
  echo "error: vm CLI not found at $CLI" >&2
  exit 1
fi

if [[ ! -d "$RECEIPTS_DIR" ]]; then
  echo "warning: no receipts directory at $RECEIPTS_DIR" >&2
fi

exec "$CLI" --profile "$PROFILE" --format "$FORMAT" audit verify
