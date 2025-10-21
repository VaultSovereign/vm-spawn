# ADR-0001: Language & Edition

**Status:** PROPOSED
**Date:** 2025-10-21
**Deciders:** Sovereign + DAO (if governance active)
**Context:** VaultMesh v5.0 evolution — Phase 1 (Hybrid)

---

## Context

VaultMesh's current Bash-based architecture has delivered v4.1-genesis successfully, but scaling demands type safety, cross-platform builds, and comprehensive testing infrastructure. We evaluated Go, Rust, and TypeScript for the v5.0 core rewrite.

**Requirements:**
- **Type safety** (prevent subtle bugs in cryptographic operations)
- **Memory safety** (no buffer overflows, no use-after-free)
- **Cross-platform** (Linux, macOS, Windows, BSD)
- **Hermetic builds** (reproducible artifacts)
- **Zero-cost abstractions** (preserve performance)
- **Ecosystem maturity** (crypto, CLI, testing, federation)

---

## Decision

**Adopt Rust 2024 edition as the implementation language for VaultMesh v5.0.**

**Workspace structure:**
```
vaultmesh/
├─ Cargo.toml                     # [workspace]
├─ crates/
│  ├─ vm-cli/                     # CLI binary (clap)
│  ├─ vm-core/                    # Domain types, JCS, Merkle
│  ├─ vm-crypto/                  # Sequoia, x509-tsp, rustls
│  ├─ vm-remembrancer/            # Storage (rusqlite|redb)
│  └─ vm-fed/                     # libp2p (feature-gated)
├─ fuzz/                          # cargo-fuzz targets
├─ tests/                         # Integration tests
└─ docs/                          # mdBook
```

**Root Cargo.toml:**
```toml
[workspace]
members = ["crates/*"]
resolver = "2"

[workspace.package]
edition = "2024"
license = "MIT OR Apache-2.0"
rust-version = "1.80"

[workspace.dependencies]
anyhow = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "1"
```

---

## Rationale

### Why Rust?

| Criterion | Rust | Go | TypeScript |
|-----------|------|----|-----------|
| Type safety | ✅ Sum types, traits | ⚠️ Interfaces only | ⚠️ Structural, runtime |
| Memory safety | ✅ Borrow checker | ⚠️ GC pauses | ❌ JS runtime |
| Performance | ✅ Zero-cost | ⚠️ GC overhead | ❌ V8 overhead |
| Crypto ecosystem | ✅ RustCrypto, Sequoia | ⚠️ Varies | ❌ Node deps |
| Cross-compile | ✅ Tier 1/2 | ✅ Good | ⚠️ Platform-specific |
| Federation (libp2p) | ✅ Native | ⚠️ go-libp2p | ⚠️ js-libp2p |
| Binary size | ✅ 5-10 MB | ⚠️ 10-20 MB | ❌ 50+ MB |

**Rust wins on:**
- Cryptographic correctness (type-safe key handling, no null pointer bugs)
- Federation readiness (libp2p is Rust-native)
- Single-binary distribution (no runtime dependencies)

### Why Rust 2024 edition?

- **Current edition** (released Dec 2024)
- **Modern idioms**: Improved async, const generics, pattern matching
- **Stable toolchain**: All features we need are stable
- **Community momentum**: Most libraries target 2021+

---

## Consequences

### Positive

✅ **Type safety eliminates entire bug classes:**
```rust
// Compile-time guarantee: key ID is non-empty, hex-formatted
#[derive(Validate)]
pub struct KeyId(#[validate(regex = r"^[0-9A-F]{16}$")] String);
```

✅ **Memory safety without GC:** Zero buffer overflows, no use-after-free

✅ **Cross-platform single binary:**
```bash
# Linux (musl, static)
cargo build --release --target x86_64-unknown-linux-musl

# macOS (universal)
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
lipo -create -output vaultmesh target/*/release/vaultmesh

# Windows
cargo build --release --target x86_64-pc-windows-msvc
```

✅ **Hermetic builds:** `cargo vendor` + `SOURCE_DATE_EPOCH` → reproducible

✅ **Rich testing:** cargo-nextest, proptest, cargo-fuzz built-in

### Negative

⚠️ **Learning curve:** Team needs Rust proficiency (3-6 months)

⚠️ **Compile times:** Larger than Go (mitigated by sccache, mold linker)

⚠️ **Dependency compilation:** First build slow (mitigated by cargo-binstall)

### Neutral

🔄 **Migration strategy:** Phase 1 (Hybrid) keeps Bash CLI as compatibility shim

🔄 **GPG interop:** Maintained via Sequoia + armored import/export

---

## Covenant Alignment

### I. INTEGRITY (Nigredo)
**Machine truth enforced by types:**
```rust
pub struct Badge {
    pub tests: TestStatus,  // Parsed from badge.json
    pub merkle_root: [u8; 32],
}
// Compiler prevents docs from hard-coding stale counts
```

### II. REPRODUCIBILITY (Albedo)
**Hermetic builds:**
```rust
pub const SOURCE_DATE_EPOCH: i64 = env!("SOURCE_DATE_EPOCH");
pub const GIT_COMMIT: &str = env!("GIT_COMMIT");
```

### III. FEDERATION (Citrinitas)
**libp2p native, JCS-canonical merge deterministic**

### IV. PROOF-CHAIN (Rubedo)
**GPG, RFC3161, Merkle preserved in Rust structs**

---

## Alternatives Considered

### 1. **Stay with Bash**
- ❌ No type safety (string soup)
- ❌ No cross-platform testing
- ❌ Shell script complexity explodes at scale

### 2. **Go**
- ✅ Good cross-compilation
- ⚠️ GC pauses unacceptable for latency-sensitive crypto ops
- ⚠️ No sum types (error handling verbose)
- ❌ libp2p less mature than Rust

### 3. **TypeScript/Deno**
- ✅ Good DX for JS devs
- ❌ Runtime dependency (Node/Deno)
- ❌ Crypto ecosystem weak (OpenSSL bindings brittle)
- ❌ Binary distribution painful (50+ MB bundles)

---

## Migration Path

**Phase 1 (v4.5 Hybrid):** Rust libraries + Bash CLI wrapper
```bash
#!/usr/bin/env bash
# vaultmesh.sh (compatibility shim)
exec vm-cli "$@"
```

**Phase 2 (v5.0 Pure Rust):** Replace Bash CLI entirely

**Phase 3 (v5.1 Federation):** libp2p + CRDT merge

**Phase 4 (v5.2 Observability):** OpenTelemetry integration

---

## References

- [Rust Edition Guide](https://doc.rust-lang.org/edition-guide/)
- [Cargo Workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html)
- [PROPOSAL_V5_EVOLUTION.md](../../PROPOSAL_V5_EVOLUTION.md)
- [RustCrypto](https://github.com/RustCrypto)
- [Sequoia OpenPGP](https://sequoia-pgp.org/)

---

**Decision:** PROCEED with Rust 2024
**Next:** ADR-0002 (Cryptography & TSA Stack)

---

🜄 **Nigredo:** The dissolution begins. The Bash relics fall away.
