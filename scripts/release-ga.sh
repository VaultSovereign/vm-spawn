#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-v1.0.0-aurora}"
KEY="${KEY:-6E4082C6A410F340}"

echo "[1/5] Build dist"
make dist KEY="$KEY"

echo "[2/5] Verify local signature & checksum"
BUNDLE=$(ls -1 dist/aurora-*.tar.gz | tail -n1)
SIG="${BUNDLE}.asc"
gpg --verify "$SIG" "$BUNDLE"
SHA=$(shasum -a 256 "$BUNDLE" | awk '{print $1}')
echo "SHA256: $SHA"
echo "$SHA  $(basename "$BUNDLE")" | tee CHECKSUMS.txt

echo "[3/5] Commit checksum manifest"
git add CHECKSUMS.txt
git commit -m "chore(release): add checksum for $(basename "$BUNDLE")" || echo "[skip] No changes to commit"

echo "[4/5] Tag GA and push"
git tag -s "$TAG" --local-user "$KEY" -m "Aurora GA – Sovereign Compute Federation"
git push origin "$TAG"

echo "[5/5] Trigger Release workflow in Actions UI with tag=$TAG"
echo "[done] bundle=$(basename "$BUNDLE"), sha256=$SHA"
