# ADR-007: GPG for Artifact Signing

**Status**: Accepted  
**Date**: 2025-10-19  
**Deciders**: VaultMesh Core Team  
**Context**: v3.0 Covenant Foundation

---

## Decision

Use OpenPGP/GnuPG detached signatures for all VaultMesh artifacts.

## Context

VaultMesh requires cryptographic signing of artifacts to achieve:
- Authenticity (verify artifact creator)
- Integrity (detect tampering)
- Non-repudiation (proof of signing)
- Sovereign key custody (no external dependencies)

### Requirements

1. **Sovereign key management**: Team controls keys without external CA
2. **Verifiable by anyone**: Anyone with public key can verify
3. **Standard tooling**: Widely available, battle-tested tools
4. **Detached signatures**: Signatures separate from artifacts
5. **CI/CD compatible**: Automatable signing in pipelines

## Alternatives Considered

### 1. X.509 Code Signing Certificates

**Pros**:
- Industry-standard for software distribution
- Built into OS trust stores
- Legal recognition in many jurisdictions

**Cons**:
- Requires Certificate Authority (CA dependency)
- Annual costs ($100-$500/year)
- Complex enrollment process
- Revocation requires CA cooperation
- Not sovereign (CA can revoke)

**Verdict**: Rejected. CA dependency conflicts with sovereignty principle.

### 2. Sigstore (cosign)

**Pros**:
- Modern supply chain security
- Transparency log (Rekor)
- OIDC-based keyless signing
- Cloud-native tooling

**Cons**:
- Relatively new (less battle-tested)
- Requires internet for signing (Rekor upload)
- OIDC dependency for keyless mode
- Key-based mode similar to GPG anyway

**Verdict**: Considered for future (Phase 4+). Compatible with GPG; can add later.

### 3. SSH Signatures (ssh-keygen -Y)

**Pros**:
- SSH keys widely used
- Simple tooling
- No additional key generation

**Cons**:
- Designed for Git commits, not artifacts
- Limited ecosystem support
- No detached signature standard
- Less mature than PGP

**Verdict**: Rejected. Insufficient tooling maturity for artifacts.

### 4. Minisign

**Pros**:
- Simple, modern design
- Small keys
- Fast

**Cons**:
- Less widespread adoption
- Fewer integrations
- No web of trust
- Limited tooling ecosystem

**Verdict**: Rejected. GPG ecosystem more mature.

## Decision Rationale

**GPG (GnuPG) chosen because**:

1. **Sovereignty**: Team generates and controls keys; no CA required
2. **Standards-based**: OpenPGP is IETF standard (RFC 4880)
3. **Tooling maturity**: 25+ years of production use
4. **Ecosystem**: Universal support (package managers, CI/CD, etc.)
5. **Detached signatures**: Perfect for artifact signing use case
6. **Verification**: `gpg --verify` works anywhere
7. **Web of trust**: Optional trust delegation model
8. **Compatibility**: Works with Sigstore if we add it later

## Implementation

### Signing Workflow

```bash
# Generate key (one-time per operator)
gpg --full-generate-key

# Sign artifact via Remembrancer
remembrancer sign artifact.tar.gz --key <key-id>

# Verify
gpg --verify artifact.tar.gz.asc artifact.tar.gz
```

### Key Management

- **Private keys**: Stored in `~/.gnupg/`, backed up encrypted offline
- **Public keys**: Shared in repository or via keyservers
- **Expiration**: 1-2 year expiration with renewal process
- **Backup**: Revocation certificates generated immediately

### CI/CD Integration

- Use gpg-agent with loopback pinentry
- Store private keys in CI secrets
- Automated signing in release pipelines
- No passphrases in environment variables

## Consequences

### Positive

- ✅ Full sovereign key custody
- ✅ No external dependencies for signing/verification
- ✅ Battle-tested, mature tooling
- ✅ Universal verification (anyone can verify)
- ✅ Transparent operations (no CA black box)

### Negative

- ⚠️ Team must manage keys (training required)
- ⚠️ Key loss = manual recovery process
- ⚠️ Web of trust not automatic (manual key exchange)
- ⚠️ Revocation requires publishing revocation certificates

### Neutral

- 🔄 Compatible with future Sigstore integration
- 🔄 Can add X.509 signatures later if legally required
- 🔄 Key rotation process must be defined

## Compliance

### Security

- Meets NIST FIPS 186-4 (RSA 3072-bit minimum)
- OpenPGP is IETF standard (RFC 4880)
- Detached signatures preserve artifact integrity

### Legal

- Admissible in court (OpenPGP widely recognized)
- Digital signature laws (e.g., eIDAS in EU) accept PGP
- Combined with RFC3161 timestamps = strong legal proof

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Key loss | Encrypted offline backups, revocation certificates |
| Key compromise | Expiration dates, immediate revocation process |
| Operator training | Comprehensive docs (COVENANT_SIGNING.md) |
| CI/CD complexity | Loopback pinentry, automated workflows |
| Web of trust gaps | Published team public keys in repository |

## Future Considerations

- **Sigstore integration** (v4.0+): Add cosign signatures alongside GPG
- **Hardware tokens** (YubiKey): Store private keys on hardware
- **Automated key rotation**: Script annual key renewal
- **Multi-signature**: Require N-of-M signatures for critical artifacts

## References

- [GnuPG Documentation](https://www.gnupg.org/documentation/)
- [RFC 4880 - OpenPGP Message Format](https://www.rfc-editor.org/rfc/rfc4880)
- [COVENANT_SIGNING.md](../../docs/COVENANT_SIGNING.md)
- [Remembrancer CLI](../bin/remembrancer)

---

**Decision**: Use GPG for sovereign, verifiable artifact signing  
**Status**: Accepted and implemented in v3.0 Covenant Foundation  
**Review Date**: 2026-10-19 (1 year)

