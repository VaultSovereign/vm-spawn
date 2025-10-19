# SECURITY — VaultMesh v4.0 Federation Foundation

## Overview

VaultMesh implements cryptographic proof chains (GPG + RFC3161 + Merkle) and federation protocols. This document outlines security requirements for production deployments.

## MCP HTTP Access Control

**Critical:** The MCP HTTP endpoint (`/mcp`) **MUST** be access-controlled in production.

### Requirements

- **Never expose `/mcp` publicly** without authentication
- Use one of these approaches:
  - **mTLS (recommended):** Client certificate authentication
  - **Reverse proxy:** nginx/Caddy with HTTP Basic Auth or OAuth2
  - **VPN/Wireguard:** Network-level isolation
  - **Service mesh:** Istio/Linkerd with mTLS policies

### Example (nginx reverse proxy)

```nginx
location /mcp {
    auth_basic "Remembrancer MCP";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://localhost:8000/mcp;
}
```

## GPG Key Management

### Private Keys

- **Never commit private keys to VCS**
- Store in:
  - `~/.gnupg/` (personal development)
  - Hardware tokens (YubiKey, Nitrokey) for production
  - Secret management (Vault, AWS Secrets Manager) for automation

### Key Operations

- Use `gpg-agent` with pinentry for passphrase caching
- Rotate keys annually or on compromise
- Maintain key revocation certificates offline

### Trust Model

- Federation peers: exchange **public keys only**
- Verify fingerprints out-of-band (phone, Signal, in-person)
- Document trust decisions in `ops/data/federation.yaml`

## TSA Certificate Authority (CA) Handling

### Policy

- **Never commit actual CA PEMs to VCS**
- Use `.example` placeholders (e.g., `freetsa-ca.pem.example`)
- Deploy actual CAs via ops automation or manual placement

### Verification

```bash
# Verify FreeTSA CA fingerprint (example)
openssl x509 -in ops/certs/freetsa-ca.pem -noout -fingerprint -sha256
# Compare with published fingerprint at https://freetsa.org/
```

### Environment Variables

- `FREETSA_CA`: Override default CA path if needed
- Document in runbooks for operators

## Federation Trust Anchors

### Per-Peer Configuration

Each peer in `ops/data/federation.yaml` requires:

```yaml
peers:
  - node_id: "peer-uuid"
    mcp_url: "https://peer.example.com/mcp"
    trust_anchor: "ops/certs/peer-pubkey.asc"  # GPG public key
```

## Strict Mode (v4.1 Preview)

**Enable hard validation on ingest** by setting in `ops/data/federation.yaml`:

```yaml
trust:
  require_signatures: true
```

**Effect:**
- Artifact/deployment memories **must** carry a valid detached GPG signature (timestamp optional)
- Invalid/missing signatures are rejected at sync time
- Non-artifact memories (ADRs, notes) remain permissive

**When to enable:**
- Production federation between known peers
- Environments with mature GPG key management
- After all peers have signing capabilities

**When to keep disabled:**
- Early development or mixed-legacy environments
- Testing federation sync with unsigned memories
- Learning/evaluation deployments

### Verification Workflow

1. Exchange public keys securely (encrypted email, Signal)
2. Verify fingerprint out-of-band
3. Add to `ops/certs/` (not committed to VCS if sensitive)
4. Update `federation.yaml`
5. Test sync with `remembrancer federation sync --peer <url>`

## Service Account Least Privilege

### RabbitMQ / NATS (Future C3L)

- Create per-service accounts with minimal permissions
- Example (RabbitMQ):
  - `remembrancer-reader`: read-only on `remembrancer.*` queues
  - `remembrancer-writer`: write-only on `remembrancer.events`
- Use separate credentials per environment (dev, staging, prod)

### Database

- SQLite: file permissions `0600` (owner read/write only)
- Postgres/MySQL: dedicated user with `SELECT, INSERT, UPDATE` only

## Incident Response

### Compromise Scenarios

| Scenario | Response |
|----------|----------|
| GPG private key leaked | Revoke key, re-sign all artifacts, notify federation peers |
| MCP endpoint exposed | Rotate auth credentials, audit access logs, review memories for tampering |
| TSA CA compromised | Switch to alternate TSA (e.g., DigiCert), re-timestamp critical artifacts |
| Peer node compromised | Remove from `federation.yaml`, audit synced memories, recompute Merkle root |

### Audit Trail

- All memory inserts logged in SQLite (`timestamp`, `merkle_root`)
- Covenant Guard CI enforces proof chains on every PR
- Pre-commit hooks block accidental credential commits

## Security Contacts

- **Maintainer:** [Your contact or security@yourdomain.com]
- **CVE Reporting:** File GitHub issue with `[SECURITY]` prefix
- **PGP Key:** [Link to public key for encrypted reports]

## Additional Resources

- [THREAT_MODEL.md](THREAT_MODEL.md) — Adversary analysis and controls
- [docs/COVENANT_HARDENING.md](docs/COVENANT_HARDENING.md) — CI and validation
- [ops/COVENANT_RITUALS.md](ops/COVENANT_RITUALS.md) — Operator cheatsheet

---

**Last Updated:** 2025-10-19 (v4.0 Phase 3)

