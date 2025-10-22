# VaultMesh Operator Checklist

## 📦 System Dependencies

### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install -y \
  pkg-config \
  libsqlite3-dev \
  nettle-dev \
  libhogweed-dev \
  libgmp-dev \
  clang \
  llvm-dev
```

### macOS
```bash
brew update
brew install pkg-config sqlite nettle gmp
```

### Windows
**Note:** Windows builds use `--no-default-features --features vm-cli/sqlite,vm-cli/tls-rustls` to skip `pgp/tsa` features (nettle/gmp not required).

```powershell
# No additional system dependencies needed for Windows basic build
# For full features, consider WSL2 with Linux dependencies
```

---

## 🜄 Daily Rites — Local Development

### Build & Verify
```bash
# Check workspace builds
cargo check --workspace

# Lint with clippy (zero warnings)
cargo clippy --workspace --all-features -- -D warnings

# Format code
cargo fmt --all

# Run all tests (unit + property + doc)
cargo nextest run --workspace --all-features
cargo test --doc --workspace --all-features

# Run property tests explicitly
cargo test --release --all-features -- proptest

# Supply-chain audit
cargo deny check
```

### Feature Combinations
```bash
# Default build (sqlite + tls-rustls)
cargo build --release

# With OpenPGP + TSA
cargo build --release --features "pgp,tsa"

# With redb instead of SQLite
cargo build --release --no-default-features --features "redb"

# All features
cargo build --release --all-features
```

---

## 🏷️ Cutting Releases

### Pre-Release Checks
```bash
# 1. Ensure all tests pass
cargo nextest run --workspace --all-features

# 2. Security audit
cargo deny check
cargo audit

# 3. Coverage check (optional)
cargo tarpaulin --workspace --all-features --out Html

# 4. Update CHANGELOG.md following Keep a Changelog format
# Add new [Unreleased] section → [X.Y.Z] - YYYY-MM-DD

# 5. Bump version in Cargo.toml files
# Update workspace.package.version in v4.5-scaffold/Cargo.toml
```

### Tag & Push (Conventional Commits)
```bash
# Commit with conventional commit message
git add -A
git commit -m "chore(release): prepare v5.0.0-alpha.2"

# Create annotated tag
git tag -a v5.0.0-alpha.2 -m "VaultMesh v5.0.0-alpha.2 — [brief description]"

# Push tag (triggers release CI)
git push origin v5.0.0-alpha.2
```

### Verify Release Artifacts
```bash
# After CI completes, download artifacts and verify attestations

# 1. Download binary and attestation from GitHub Release
gh release download v5.0.0-alpha.2

# 2. Verify SLSA attestation
gh attestation verify vm-cli-linux-amd64 --owner VaultSovereign

# 3. Verify cosign signature (if enabled)
cosign verify-blob \
  --bundle vm-cli-linux-amd64.cosign-bundle \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity "https://github.com/VaultSovereign/vm-spawn/.github/workflows/rust-ci.yml@refs/tags/v5.0.0-alpha.2" \
  vm-cli-linux-amd64
```

---

## 🔒 Crypto Validation Rituals

### JCS Canonicalization
```bash
# Ensure content-id is stable
vaultmesh canon --in receipt.json --out receipt.jcs
shasum -a 256 receipt.jcs

# Verify round-trip stability
vaultmesh canon --in receipt.jcs --out - | diff - receipt.jcs
```

### OpenPGP Detached Signatures (Sequoia)
```bash
# Sign with Sequoia-based CLI
vaultmesh sign --key signing-key.asc --detach receipt.jcs > receipt.sig

# Verify with system GPG (compatibility check)
gpg --verify receipt.sig receipt.jcs

# Verify with Sequoia sq
sq verify --signature-file receipt.sig receipt.jcs --signatures 1
```

### RFC3161 Timestamp Tokens
```bash
# Request timestamp
vaultmesh timestamp --input receipt.jcs --tsa https://freetsa.org/tsr > receipt.tsr

# Verify timestamp token
vaultmesh timestamp-verify --token receipt.tsr --input receipt.jcs
```

---

## 🛠️ Troubleshooting

### CI Failures

**Clippy warnings:**
```bash
# Show all warnings locally
cargo clippy --workspace --all-features --all-targets -- -D warnings

# Fix auto-fixable issues
cargo clippy --fix --workspace --all-features
```

**Deny failures (advisories):**
```bash
# Show detailed report
cargo deny check advisories --show-stats

# If advisory is false positive, add to deny.toml
```

**Test failures:**
```bash
# Run failing test with backtrace
RUST_BACKTRACE=1 cargo test test_name -- --nocapture

# Run property test with verbose output
cargo test proptest_name -- --nocapture --test-threads=1
```

### Build Issues

**Cross-compilation errors:**
```bash
# Install target
rustup target add x86_64-unknown-linux-musl

# Build with verbose output
cargo build --target x86_64-unknown-linux-musl --verbose
```

**Dependency resolution:**
```bash
# Update Cargo.lock
cargo update

# Check for duplicate dependencies
cargo tree --duplicates

# Prune unused dependencies
cargo machete  # requires cargo install cargo-machete
```

---

## 📊 Metrics & Monitoring

### Coverage
```bash
# Generate HTML report
cargo tarpaulin --workspace --all-features --out Html

# Open in browser
open tarpaulin-report.html
```

### Performance Profiling
```bash
# Build with profiling symbols
cargo build --release --profile=profiling

# Profile with flamegraph (requires cargo-flamegraph)
cargo flamegraph --bin vm-cli -- record --component test --version 1.0
```

### Binary Size Analysis
```bash
# Check binary size
ls -lh target/release/vm-cli

# Analyze with cargo-bloat
cargo bloat --release -p vm-cli --crates
```

---

## 🧬 Covenant Checkpoints

### Before Merge
- [ ] All tests pass (unit + property + doc)
- [ ] Clippy clean with `-D warnings`
- [ ] `cargo fmt` applied
- [ ] `cargo deny check` passes
- [ ] Coverage ≥ 80% (tarpaulin)
- [ ] CHANGELOG.md updated
- [ ] ADRs reviewed (if new decisions)

### Before Release
- [ ] Version bumped in Cargo.toml
- [ ] Git tag created (annotated, signed)
- [ ] CI release job passes
- [ ] SLSA attestations generated
- [ ] Artifacts downloadable from GitHub Release
- [ ] Attestations verifiable with `gh attestation verify`
- [ ] Cosign signature verifiable (if enabled)

### After Release
- [ ] Release notes published
- [ ] Announcement posted (if applicable)
- [ ] Documentation updated (if breaking changes)
- [ ] Next version milestone created

---

## 🔗 Quick Links

- **CI Status**: https://github.com/VaultSovereign/vm-spawn/actions
- **Releases**: https://github.com/VaultSovereign/vm-spawn/releases
- **RustSec Advisory DB**: https://rustsec.org/
- **Sequoia-PGP Docs**: https://sequoia-pgp.org/
- **RFC 8785 (JCS)**: https://www.rfc-editor.org/rfc/rfc8785
- **RFC 3161 (TSP)**: https://www.rfc-editor.org/rfc/rfc3161

---

🜄 **Solve et Coagula** — The operator's covenant: verify, attest, release.
