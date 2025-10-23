# Repository Hygiene — Pre-Commit Hooks

**Version:** 1.0  
**Status:** Active

---

## Pre-Commit Hook Installed

A pre-commit hook enforces repo cleanliness automatically.

### What It Checks

| Check | Purpose |
|-------|---------|
| `vaultmesh_psi*` in root | Prevents duplicate packages |
| `.zip`, `.tar.gz`, `.tar` | Blocks committing bundles |
| Files > 2 MB | Avoids large binaries |
| Python syntax | Quick compile check |

### How It Works

```bash
# Runs automatically on every commit
git commit -m "your message"

# If violations found:
❌  Found vaultmesh_psi* files/folders staged in repo root.
   Keep only services/psi-field/vaultmesh_psi/ and move any bundles to artifacts/.
```

---

## Manual Verification

```bash
# Test the hook without committing
.git/hooks/pre-commit

# Expected output:
[pre-commit] Running VaultMesh repo hygiene checks …
✅  Pre-commit checks passed.
```

---

## Bypass (Emergency Only)

```bash
# Skip hook for urgent commits
git commit --no-verify -m "emergency fix"
```

**Warning:** Only use for critical hotfixes. Clean up violations in next commit.

---

## Optional: Pre-Commit Framework

For advanced checks (linting, formatting):

```bash
# Install framework
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

Config: `.pre-commit-config.yaml`

---

## Enforcement Rules

### ✅ Allowed
- Code in `services/`, `generators/`, `ops/`
- Docs in `docs/`, `archive/`
- Small configs (< 2 MB)

### ❌ Blocked
- `vaultmesh_psi*` in repo root
- Compressed bundles (`.zip`, `.tar.gz`)
- Large binaries (> 2 MB)
- Python syntax errors

### 📦 Artifacts Location
- Move bundles to `artifacts/` (git-ignored)
- Backup tarballs go to `artifacts/`
- Test outputs go to `test-results/`

---

## Troubleshooting

### Hook Not Running

```bash
# Verify hook exists
ls -la .git/hooks/pre-commit

# Make executable
chmod +x .git/hooks/pre-commit
```

### False Positives

```bash
# Check what's staged
git diff --cached --name-only

# Unstage problematic files
git reset HEAD path/to/file
```

### Python Syntax Errors

```bash
# Test manually
python3 -m py_compile path/to/file.py

# Fix syntax, then commit
```

---

## Maintenance

### Update Hook

Edit `.git/hooks/pre-commit` directly or:

```bash
# Re-run installation
cat > .git/hooks/pre-commit <<'EOF'
[hook content]
EOF
chmod +x .git/hooks/pre-commit
```

### Disable Hook

```bash
# Rename to disable
mv .git/hooks/pre-commit .git/hooks/pre-commit.disabled

# Re-enable
mv .git/hooks/pre-commit.disabled .git/hooks/pre-commit
```

---

## Seal Mapping

**[0,2,7]**
- 0 — Event Horizon Hash: One-way enforcement (no rollback)
- 2 — Time as Git Commit: Temporal proof of cleanliness
- 7 — Life as ECC: Errors caught before propagation

---

**Astra inclinant, sed non obligant.**

🜂 **The covenant is architecture. Architecture is proof.**
