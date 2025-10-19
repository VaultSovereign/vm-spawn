# Covenant Signing (v3.0)

## Why GPG?

- **Sovereign key custody**: No external Certificate Authority required
- **Team-to-team verification**: Share public keys directly
- **Detached signatures**: Signatures travel with artifacts; verify anywhere
- **Standard tooling**: OpenPGP is widely supported and battle-tested

## Generate a GPG Key

```bash
# Interactive key generation
gpg --full-generate-key

# Quick key generation (for testing)
gpg --quick-generate-key "Your Name <your@email.com>" rsa3072 sign 1y

# List your keys
gpg --list-keys
```

## Sign an Artifact

```bash
# Sign with the Remembrancer
remembrancer sign dist/artifact.tar.gz --key <your-key-id>
# Creates: dist/artifact.tar.gz.asc

# Manual signing (if needed)
gpg --batch --yes --armor --detach-sign \
  --local-user <your-key-id> \
  --output artifact.tar.gz.asc \
  artifact.tar.gz
```

## Verify a Signature

```bash
# Verify with GPG directly
gpg --verify dist/artifact.tar.gz.asc dist/artifact.tar.gz

# Verify with the Remembrancer (full chain)
remembrancer verify-full dist/artifact.tar.gz
```

## Export and Share Public Keys

```bash
# Export your public key (ASCII-armored)
gpg --armor --export <your-key-id> > team-pubkey.asc

# Import a team member's public key
gpg --import team-member-pubkey.asc

# Trust the imported key (optional, for full verification)
gpg --edit-key <key-id>
# At the prompt: trust → 5 (ultimate) → quit
```

## Best Practices

### Security

- **Use gpg-agent**: Never pass passphrases on the command line
- **Enable pinentry**: Use TTY or GUI pinentry for secure passphrase entry
- **Backup your keys**: Store private keys in encrypted, offline storage
- **Key expiration**: Set reasonable expiration dates (1-2 years)
- **Revocation certificate**: Generate and store offline immediately after key creation

### Operational

- **CI/CD environments**: Use environment-controlled loopback pinentry or key-less signing
- **Key rotation**: Plan for regular key rotation (annually or bi-annually)
- **Team coordination**: Publish public keys in repository or centralized PKI
- **Verification requirements**: Establish team policy on signature verification

## Key Management

### Generate Revocation Certificate

```bash
gpg --output revoke.asc --gen-revoke <your-key-id>
# Store this certificate securely offline
```

### Backup Private Key

```bash
gpg --export-secret-keys --armor <your-key-id> > private-key-backup.asc
# Encrypt this file and store securely
```

### Restore from Backup

```bash
gpg --import private-key-backup.asc
```

## Troubleshooting

### "No secret key" error

```bash
# List secret keys
gpg --list-secret-keys

# If missing, import your private key
gpg --import <private-key-file>
```

### gpg-agent not running

```bash
# Start gpg-agent
gpgconf --launch gpg-agent

# Check status
gpgconf --check-programs
```

### Pinentry issues in CI

```bash
# Use loopback pinentry for non-interactive environments
echo "allow-loopback-pinentry" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
export GPG_TTY=$(tty)
```

## References

- [GnuPG Documentation](https://www.gnupg.org/documentation/)
- [OpenPGP Best Practices](https://riseup.net/en/security/message-security/openpgp/best-practices)
- [The Remembrancer CLI](../ops/bin/remembrancer)

---

**Status**: Implemented in v3.0 Covenant Foundation  
**ADR**: See [ADR-007: GPG for Artifact Signing](../ops/receipts/adr/ADR-007-gpg-over-x509.md)

