# Federation Operations

## Deploy
1. Configure `vmsh/config/federation.yaml` and `vmsh/config/peers.yaml`.
2. Start the daemon: `make federation`.
3. Validate connectivity: `npx ts-node tools/vmsh-federation.ts status`.

## Failures
- Announce failures: φ-backoff and peer banlist (future).
- Verification failures: imported but not activated; logged for SOAR.

## Incident Playbooks
- Reorg detected: re-verify anchors; supersede weaker attestations; re-announce.
- Peer misbehavior: remove DID from allowlist; rotate keys; audit logs.
