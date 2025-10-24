# 🚨 Security Incident Report: Exposed Cloudflare API Token

**Date:** 2025-10-24
**Severity:** P0 - Critical
**Status:** ⚠️ Mitigation in progress

---

## Incident Summary

Cloudflare API token was hardcoded in `setup-cloudflare-dns.sh` and committed to git repository, exposing it in:
- Git history (commit `4bb42bb`)
- GitHub PR #19 (public)
- Potentially in any clones/forks

---

## Exposed Credentials

**Token:** `VgYJj9TIKqh8v62dnqEcRyHjlqO2voO3InHsL0gK`
**Zone ID:** `8276372d1df87af19b7b595f1c419219` (vaultmesh.cloud - public, not sensitive)
**Exposure Time:** ~30 minutes
**Repository:** github.com/VaultSovereign/vm-spawn

---

## Impact Assessment

### What Could Be Compromised
- **DNS Records:** Attacker could modify/delete DNS records for vaultmesh.cloud
- **Domain Configuration:** Cloudflare settings for the zone
- **SSL Certificates:** Could be revoked or modified
- **Traffic Routing:** DNS hijacking potential

### What is NOT Compromised
- GCP infrastructure (separate credentials)
- Kubernetes cluster access
- Service accounts
- Docker images
- Other secrets (properly managed)

---

## Immediate Actions Required

### 1. Rotate Cloudflare API Token (URGENT)
```bash
# In Cloudflare Dashboard:
1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Find the exposed token
3. Revoke it immediately
4. Create new token with same permissions:
   - Zone.DNS (Edit)
   - Zone.Zone (Read)
   - Scope: vaultmesh.cloud only
```

### 2. Update Local Configuration
```bash
# Store new token securely
mkdir -p ~/.vaultmesh
echo 'export CF_API_TOKEN="NEW_TOKEN_HERE"' > ~/.vaultmesh/cloudflare.env
chmod 600 ~/.vaultmesh/cloudflare.env

# Add to .gitignore
echo "~/.vaultmesh/cloudflare.env" >> ~/.gitignore
```

### 3. Fix Git History (Optional but Recommended)
```bash
# Remove from git history using BFG Repo-Cleaner or git filter-repo
# WARNING: This rewrites history - coordinate with team

git filter-repo --path setup-cloudflare-dns.sh --invert-paths
# Or use BFG:
bfg --replace-text <(echo 'VgYJj9TIKqh8v62dnqEcRyHjlqO2voO3InHsL0gK==>REDACTED')
```

### 4. Update PR #19
```bash
# Amend the commit to remove hardcoded token
git commit --amend
git push -f origin feat/gcp-production-analytics
```

---

## Preventive Measures Implemented

### ✅ Code Changes
1. **setup-cloudflare-dns.sh** - Now reads from environment variable
2. **Credential Check** - Script exits if CF_API_TOKEN not set
3. **Documentation** - Clear instructions for secure token storage

### ✅ .gitignore Updates
```gitignore
# Cloudflare credentials
.env
.env.*
*.env
cloudflare.env
secrets/
~/.vaultmesh/cloudflare.env
```

### ✅ Documentation
- Added setup instructions with secure credential handling
- Updated GCP_DEPLOYMENT_STATUS.md with security notes

---

## Future Prevention

### 1. Pre-commit Hooks
Add secret scanning:
```bash
# Install gitleaks or detect-secrets
pip install detect-secrets

# Run before commit
detect-secrets scan
```

### 2. CI/CD Scanning
Add to GitHub Actions:
```yaml
- name: Secret Scanning
  uses: trufflesecurity/trufflehog@main
  with:
    path: ./
```

### 3. Secret Management
Use proper secret management:
- **SOPS** - For encrypted secrets in git (already configured in `.sops.yaml`)
- **Vault** - HashiCorp Vault for runtime secrets
- **GCP Secret Manager** - For GCP-specific secrets
- **Environment Variables** - For local development

### 4. Code Review Checklist
Add to PR template:
- [ ] No hardcoded credentials
- [ ] No API tokens in code
- [ ] Secrets use environment variables
- [ ] .gitignore updated if needed

---

## Timeline

| Time | Event |
|------|-------|
| 20:16 UTC | Token hardcoded in commit `4bb42bb` |
| 20:30 UTC | PR #19 created (public) |
| 20:46 UTC | **Incident discovered** |
| 20:47 UTC | Mitigation started |
| TBD | Token rotation (waiting on user action) |

---

## Action Items

### Critical (Do NOW)
- [ ] **Rotate Cloudflare API token** in Cloudflare dashboard
- [ ] Update `~/.vaultmesh/cloudflare.env` with new token
- [ ] Verify DNS records haven't been tampered with

### High Priority (Next Hour)
- [ ] Force-push fixed commit to PR #19
- [ ] Add secret scanning to CI/CD
- [ ] Update `.gitignore` with secret patterns
- [ ] Document secure credential setup

### Medium Priority (Next Day)
- [ ] Consider rewriting git history to remove token
- [ ] Set up proper secret management (SOPS/Vault)
- [ ] Add pre-commit hooks for secret detection
- [ ] Update PR review checklist

---

## Lessons Learned

1. **Never hardcode secrets** - Even for "helper scripts"
2. **Use environment variables** - From day one
3. **Pre-commit scanning** - Would have caught this
4. **Code review** - Should catch hardcoded credentials
5. **SOPS is already configured** - Should have used it

---

## Reference

### Secure Credential Storage Pattern
```bash
# Good: Environment variable
CF_API_TOKEN="${CF_API_TOKEN:-}"

# Good: SOPS encrypted file
sops -e secrets/cloudflare.yaml

# Bad: Hardcoded
CF_API_TOKEN="actual-token-here"  # ❌ NEVER DO THIS
```

### SOPS Usage (Already Configured)
```bash
# Encrypt secrets
sops -e secrets/cloudflare.yaml > secrets/cloudflare.enc.yaml

# Decrypt for use
export CF_API_TOKEN=$(sops -d secrets/cloudflare.enc.yaml | yq .api_token)
```

---

## Status: ⚠️ WAITING FOR TOKEN ROTATION

**Next Step:** User must rotate Cloudflare API token immediately.

🜂 **The Remembrancer remembers - even security incidents. This is now institutional memory.**
