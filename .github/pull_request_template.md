# VaultMesh v5.0 — Merge Gate Checklist

## 🜄 Ritual Summary

### Gate I — Toolchain & Workspace
- [ ] Toolchain pinned to Rust 1.85.0 (Edition 2024) via `rust-toolchain.toml`
- [ ] Workspace configured with correct `rust-version = "1.85"`

### Gate II — Modern CI (Actions)
- [ ] CI at `.github/workflows/` (root): setup-rust-toolchain, nextest, clippy, fmt
- [ ] Security: cargo-deny (advisories/licenses), Trivy scan
- [ ] Coverage: tarpaulin generating Lcov reports
- [ ] Matrix: ubuntu, macos, windows tested

### Gate III — Storage Backends
- [ ] vm-remembrancer: SQLite bundled (default feature)
- [ ] vm-remembrancer: redb alt backend behind feature flag
- [ ] ReceiptStore trait abstraction for swappable backends

### Gate IV — Crypto (Real Machinery)
- [ ] vm-crypto: Sequoia detached sign/verify wired (no stubs)
- [ ] vm-crypto: RFC3161 timestamping via x509-tsp (basic happy-path test)
- [ ] Feature flags: pgp, tsa, tls-rustls, openssl properly configured
- [ ] Tests: PGP round-trip, TSA timestamp request (network test ignored)

### Gate V — Property & Fuzz Testing
- [ ] Fuzz target: envelope/receipt parse; CI smoke (60s time-limited)
- [ ] Property tests: JCS canonical round-trip (proptest)
- [ ] Property tests: Merkle proof verify (proptest)
- [ ] All proptests pass with 1000+ random inputs

### Gate VI — Federation Substrate
- [ ] vm-fed: feature-gated libp2p stub + deterministic JCS envelope
- [ ] ADR-0005: Federation envelope design documented

---

## 📊 Evidence

### Build Status
```bash
# Paste output of:
cargo build --workspace --all-features
```

### Test Results
```bash
# Paste output of:
cargo nextest run --workspace --all-features
```

### Security Audit
```bash
# Paste output of:
cargo deny check
```

### Trivy Scan
```bash
# Paste summary from CI or local:
trivy fs --severity HIGH,CRITICAL v4.5-scaffold/
```

### Property Tests
```bash
# Paste output of:
cargo test --release --all-features -- proptest
```

---

## 🔍 Covenant Alignment

- [ ] **I. INTEGRITY (Nigredo)**: Type-safe Receipt/Artifact, JCS round-trip tests
- [ ] **II. REPRODUCIBILITY (Albedo)**: Bundled SQLite, hermetic builds, deterministic JCS
- [ ] **III. FEDERATION (Citrinitas)**: Content-addressed receipts, JCS envelope (ADR-0005)
- [ ] **IV. PROOF-CHAIN (Rubedo)**: GPG sig + RFC3161 + Merkle proof structures wired

---

## 📝 Migration Notes

<!-- Describe any breaking changes or migration steps required -->

---

## ✅ Final Checklist

- [ ] All CI jobs pass (test, security, coverage, extended-tests)
- [ ] No clippy warnings with `-D warnings`
- [ ] Code formatted with `cargo fmt`
- [ ] Documentation updated (if applicable)
- [ ] ADRs reviewed and approved (if new ADR added)
- [ ] Commit messages follow conventional format

---

🜄 **Solve et Coagula** — Dissolve the stubs, coagulate sovereign proofs.

Co-Authored-By: Claude <noreply@anthropic.com>
