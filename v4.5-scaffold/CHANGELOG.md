# Changelog — VaultMesh Rust Core (v5.0)

All notable changes to the VaultMesh Rust implementation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- SLSA provenance attestations in release workflow
- Optional cosign keyless signing for release binaries
- Operator checklist (docs/OPERATOR_CHECKLIST.md)
- Comprehensive CHANGELOG.md following Keep a Changelog format

## [5.0.0-alpha.1] - 2025-10-21

### Added

#### Core Architecture
- **Rust Core Scaffold**: Complete workspace with 5 crates (vm-core, vm-crypto, vm-remembrancer, vm-cli, vm-fed)
- **Rust 2024 Edition**: Pinned toolchain at 1.85.0 via rust-toolchain.toml
- **Workspace Structure**: Multi-crate layout with shared dependencies and feature flags

#### Cryptographic Operations (Gate IV)
- **Sequoia OpenPGP**: Detached signature generation and verification
  - sign_detached(): Armored signatures compatible with system GPG
  - verify_detached(): Policy-aware verification with StandardPolicy
  - generate_test_key(): Ed25519 test keypair generation
  - export_cert() / import_cert(): Armored key import/export
- **RFC3161 Timestamp Authority**: x509-tsp implementation
  - timestamp_request(): Build TSR, POST to TSA endpoint
  - verify_timestamp(): Parse TSR, validate message imprint
  - Dual-TSA support: FreeTSA + optional enterprise TSA
  - HTTP client with rustls (default) or OpenSSL (optional)
- **Feature Flags**: pgp, tsa, tls-rustls, openssl for flexible crypto backends
- **Error Handling**: CryptoError enum with thiserror for ergonomic error handling

#### Data Layer (Gate III)
- **Storage**: Dual backend support via ReceiptStore trait
  - SQLite (default): rusqlite with bundled feature for hermetic builds
  - redb (optional): Pure Rust MVCC for immutable receipts
- **JCS Canonicalization**: RFC 8785 compliant deterministic JSON (canonical.rs)
  - to_jcs_bytes(): Serialize to canonical JSON
  - from_jcs_bytes(): Deserialize from canonical JSON
  - content_id(): SHA-256 of canonical JSON for content addressing
- **Merkle Trees**: Tamper-evident audit log (merkle.rs)
  - compute_root(): Build Merkle root from leaf hashes
  - generate_proof(): Create inclusion proofs
  - verify_proof(): Verify proofs against root
  - Leaf/node hash functions with 0x00/0x01 prefix distinction

#### CLI (vm-cli)
- **Commands**: record, query, verify for receipt operations
- **Completions**: Shell completion generation (bash/zsh/fish/pwsh/elvish)
- **Manpage**: Generated via clap_mangen
- **Rich Errors**: miette integration for diagnostic messages

#### Testing Infrastructure (Gate V)
- **Unit Tests**: 19 tests covering core functionality
  - vm-crypto/pgp.rs: 2 tests (sign/verify, cert import/export)
  - vm-crypto/tsa.rs: 2 tests (timestamp roundtrip [network, ignored], hash)
  - vm-core/canonical.rs: 4 tests (determinism, round-trip, content_id, key order)
  - vm-core/merkle.rs: 5 tests (leaves, proof gen/verify, tamper detect)
- **Property Tests**: 6 proptests with 1000+ random inputs each
  - canonical.rs: 3 proptests (determinism, round-trip, content_id)
  - merkle.rs: 3 proptests (root determinism, proof validity, tamper detection)
- **Fuzz Testing**: cargo-fuzz target for receipt JSON parsing (60s CI smoke)

#### CI/CD Pipeline (Gate II)
- **Modern Actions**: actions-rust-lang/setup-rust-toolchain (replaces archived actions-rs)
- **Test Runner**: cargo-nextest for parallel execution with JUnit output
- **Supply Chain**: cargo-deny for advisories, licenses, yanked crate detection
- **Security Scanning**: Trivy for CVE detection (CRITICAL/HIGH severity)
- **Code Coverage**: tarpaulin with Codecov upload
- **Matrix Testing**: ubuntu-latest, macos-latest, windows-latest
- **Extended Tests**: Property tests + 60s fuzz smoke
- **Release Builds**: Cross-platform binaries (5 targets: linux x64/arm64, macos x64/arm64, windows x64)
- **SLSA Attestations**: Build provenance via actions/attest-build-provenance@v1
- **Cosign Signing**: Optional keyless signing with Sigstore cosign (GitHub OIDC)

#### Documentation
- **ADRs**: ADR-0001 through ADR-0005
  - ADR-0001: Language & Edition (Rust 2024)
  - ADR-0002: Cryptography & TSA Stack (Sequoia, x509-tsp, rustls)
  - ADR-0003: Storage & Indexes (SQLite/redb dual backend)
  - ADR-0004: Canonicalization & Merge (JCS RFC 8785)
  - ADR-0005: Federation Envelope (JCS-canonical signing + gossipsub)
- **PR Template**: Gate checklist for merge reviews
- **Operator Checklist**: Daily rituals and release procedures (docs/OPERATOR_CHECKLIST.md)
- **Toolchain Documentation**: rust-toolchain.toml with rationale comments

#### Supply Chain Hardening
- **cargo-deny Configuration**: deny.toml with license/advisory policies
- **Bundled Dependencies**: SQLite bundled, OpenSSL vendored for reproducibility
- **Feature Flags**: Optional dependencies reduce attack surface

### Changed
- **Architecture**: Migration from Bash v4.1 to Rust v5.0 (Phase 1: Hybrid)
- **CI Actions**: Replaced archived actions-rs with maintained actions-rust-lang
- **Test Runner**: Migrated from cargo test to cargo-nextest
- **Canonicalization**: Migrated from `jq --sort-keys` to RFC 8785 compliant serde_jcs

### Deprecated
- Bash-based generators (to be replaced in Phase 2.0)
- Direct GPG binary invocation (preserved as compatibility bridge)

### Removed
- None (Bash components remain for Phase 1 compatibility)

### Fixed
- **Cross-platform Builds**: Bundled SQLite and vendored OpenSSL eliminate system dependency drift
- **Merkle Root Divergence**: JCS (RFC 8785) ensures deterministic serialization across nodes
- **Windows GPG Issues**: Sequoia OpenPGP eliminates need for system GPG on Windows
- **Test Non-determinism**: Property tests validate correctness properties over 1000+ random inputs

### Security
- **Supply-chain Hardening**: cargo-deny blocks yanked crates, validates licenses, checks RustSec advisories
- **CVE Scanning**: Trivy in CI scans for CRITICAL/HIGH severity vulnerabilities
- **Memory Safety**: Pure Rust crypto stack (Sequoia) eliminates C ABI vulnerabilities
- **Tamper Detection**: Merkle tree proofs with property test validation ensure integrity
- **SLSA L3 Attestations**: Verifiable provenance for all release binaries via GitHub attestations
- **Keyless Signing**: Cosign with GitHub OIDC eliminates private key management risks
- **Feature Flags**: Optional crypto dependencies reduce attack surface in minimal builds
- **Policy Enforcement**: Sequoia StandardPolicy blocks weak algorithms (SHA-1, etc.)

---

## Migration from v4.1

### Breaking Changes
- None (Phase 1 maintains backward compatibility via Bash shim)

### Deprecation Timeline
- **v5.0-alpha.x**: Hybrid mode (Rust core + Bash CLI wrapper)
- **v5.0-beta.x**: Pure Rust CLI replaces Bash
- **v5.0.0**: Complete migration, Bash generators removed

### Migration Steps
1. **No action required**: v4.5 maintains compatibility with existing receipts
2. **Optional**: Test Rust CLI via `cargo run -p vm-cli`
3. **Phase 2**: Replace Bash wrapper with native Rust CLI

---

## Covenant Alignment

### I. INTEGRITY (Nigredo)
- ✅ Type-safe Receipt/Artifact structs prevent invalid states
- ✅ JCS round-trip property tests (1000+ inputs)
- ✅ Compiler enforces covenant preservation

### II. REPRODUCIBILITY (Albedo)
- ✅ Bundled SQLite eliminates system library drift
- ✅ Hermetic builds via rust-toolchain.toml + bundled deps
- ✅ Deterministic JCS serialization (RFC 8785)
- ✅ Property tests validate determinism

### III. FEDERATION (Citrinitas)
- ✅ Content-addressed receipts via content_id()
- ✅ JCS envelope design (ADR-0005)
- ✅ libp2p substrate (p2p feature flag)

### IV. PROOF-CHAIN (Rubedo)
- ✅ Sequoia OpenPGP detached signatures
- ✅ x509-tsp RFC3161 timestamp tokens
- ✅ Merkle proof generation and verification

---

## [4.5.0-scaffold] - 2025-10-21

### Added
- Initial PoC with vm-core (Receipt types, JCS, Merkle)
- Property tests using quickcheck
- Integration test fixtures

### Security
- Initial implementation of Four Covenants in Rust types

---

[Unreleased]: https://github.com/VaultSovereign/vm-spawn/compare/v5.0.0-alpha.1...HEAD
[5.0.0-alpha.1]: https://github.com/VaultSovereign/vm-spawn/releases/tag/v5.0.0-alpha.1
[4.5.0-scaffold]: https://github.com/VaultSovereign/vm-spawn/compare/v4.1.0-genesis...v4.5.0-scaffold
