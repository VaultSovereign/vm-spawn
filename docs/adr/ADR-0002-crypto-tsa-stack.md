# ADR-0002: Cryptography & TSA Stack

**Status:** PROPOSED
**Date:** 2025-10-21
**Deciders:** Sovereign + DAO (if governance active)
**Context:** VaultMesh v5.0 evolution — Cryptographic sovereignty

---

## Context

VaultMesh's proof-chain (Covenant IV: Rubedo) requires:
1. **OpenPGP signatures** (detached, verifiable by any GPG user)
2. **RFC3161 timestamps** (dual-TSA: public + optional enterprise)
3. **TLS for TSA communication** (SPKI-pinned, secure by default)
4. **JCS canonicalization** (deterministic JSON for Merkle/federation)

**Current v4.1 approach:**
- Shell out to `gpg` binary for sign/verify
- Shell out to `openssl ts` for timestamp requests/responses
- Shell out to `curl` for TSA HTTP
- Shell out to `jq` for JSON canonicalization

**Problems:**
- ❌ System dependency hell (Windows GPG installs fragile)
- ❌ No type safety (key IDs are strings, easy to mix up)
- ❌ Hard to test (mocking shell calls painful)
- ❌ Cross-platform pain (OpenSSL vs LibreSSL vs BoringSSL)

---

## Decision

**Adopt pure-Rust cryptography with optional system GPG bridge:**

| Component | Library | Rationale |
|-----------|---------|-----------|
| **OpenPGP** | Sequoia-PGP 1.x | Native Rust, actively maintained, designed for programmatic use |
| **RFC3161** | x509-tsp 0.3+ | RustCrypto project, TSR/TSQ support |
| **TLS (primary)** | rustls 0.23+ | Pure Rust, aws-lc-rs backend, FIPS-friendly posture |
| **TLS (fallback)** | OpenSSL 0.10 (vendored) | For legacy TSAs requiring OpenSSL quirks |
| **JSON Canon** | serde_jcs | RFC 8785 (JCS) compliant, deterministic |
| **SHA-256** | sha2 (RustCrypto) | FIPS 140-3 validated (aws-lc-rs backend) |

**Feature flags:**
```toml
[features]
default = ["tls-rustls", "openpgp-native"]
openpgp-native = ["dep:sequoia-openpgp"]
gpg-compat = ["sequoia-openpgp/allow-weak-hashes"]  # For legacy key import
tls-rustls = ["dep:rustls", "dep:aws-lc-rs"]
tls-openssl = ["dep:openssl"]
```

---

## Rationale

### 1. Sequoia OpenPGP over GPG shelling

**Sequoia advantages:**
```rust
use sequoia_openpgp as openpgp;

// Type-safe key handling
pub struct SigningKey {
    cert: openpgp::Cert,
    key: openpgp::packet::Key<openpgp::packet::key::SecretParts, _>,
}

// Detached signature (armored)
pub fn sign_detached(key: &SigningKey, data: &[u8]) -> Result<String> {
    let mut sink = Vec::new();
    let message = openpgp::Message::new(&mut sink);
    let mut signer = openpgp::crypto::Signer::new(message, key)?;
    signer.write_all(data)?;
    signer.finalize()?;
    Ok(openpgp::armor::Writer::new(&mut sink, openpgp::armor::Kind::Signature)?)
}
```

**Benefits:**
- ✅ **Type safety:** Key ID is `openpgp::KeyID`, not `String`
- ✅ **No shell injection:** No `gpg --batch --sign` string building
- ✅ **Portable:** Works on Windows without Gpg4win
- ✅ **Testable:** Mock key pairs trivially

**GPG compatibility maintained:**
```rust
// Import existing GPG keys (armored)
let cert = openpgp::Cert::from_armor(gpg_armored_key)?;

// Export for GPG verification
let armored = cert.armored().to_vec()?;
std::fs::write("pubkey.asc", armored)?;
// $ gpg --import pubkey.asc
```

---

### 2. x509-tsp for RFC3161

**RustCrypto x509-tsp:**
```rust
use x509_tsp::{TimeStampReq, TimeStampResp};

// Create TSR request
let req = TimeStampReq::builder()
    .message_imprint(sha256_hash, DigestAlgorithm::Sha256)
    .cert_req(true)
    .build()?;

// Send via HTTP (reqwest)
let resp_bytes = reqwest::blocking::Client::new()
    .post("https://freetsa.org/tsr")
    .header("Content-Type", "application/timestamp-query")
    .body(req.to_der()?)
    .send()?
    .bytes()?;

// Parse and verify
let resp = TimeStampResp::from_der(&resp_bytes)?;
let token = resp.token()?;
let tst = token.tst_info()?;
assert_eq!(tst.message_imprint().digest(), sha256_hash);
```

**Benefits:**
- ✅ **Type-safe:** TST info parsed into structs
- ✅ **No OpenSSL shell:** Pure Rust parsing
- ✅ **Dual-TSA trivial:** Map over TSA URLs

---

### 3. rustls over OpenSSL (where possible)

**Why rustls?**
- ✅ **Memory safe:** No Heartbleed-class bugs
- ✅ **Smaller attack surface:** 100k LoC vs OpenSSL's 500k
- ✅ **aws-lc-rs backend:** FIPS 140-3 validated crypto
- ✅ **No system deps:** Compiles everywhere

**When to use OpenSSL feature:**
- ⚠️ Legacy TSA requires specific cipher suites
- ⚠️ SPKI pinning requires OpenSSL's X509 APIs

**Implementation:**
```rust
#[cfg(feature = "tls-rustls")]
fn http_client() -> reqwest::blocking::Client {
    reqwest::blocking::Client::builder()
        .use_rustls_tls()
        .build()?
}

#[cfg(feature = "tls-openssl")]
fn http_client() -> reqwest::blocking::Client {
    reqwest::blocking::Client::builder()
        .use_native_tls()  // Falls back to OpenSSL on Linux
        .build()?
}
```

---

### 4. JCS (RFC 8785) for canonical JSON

**serde_jcs:**
```rust
use serde_jcs;

#[derive(Serialize)]
pub struct Receipt {
    pub component: String,
    pub version: String,
    pub sha256: [u8; 32],
}

// Deterministic serialization
let canonical = serde_jcs::to_vec(&receipt)?;
let hash = sha256(&canonical);
```

**Why JCS over alternatives?**
- ✅ **RFC standard:** Not ad-hoc (unlike jq's sort_keys)
- ✅ **Deterministic:** Object keys sorted, no whitespace
- ✅ **Round-trip stable:** Parse → canonicalize → parse = identical

**This enables:**
- Merkle root stability across nodes
- Federation merge without diff noise
- Content-addressed receipts

---

## Consequences

### Positive

✅ **Zero system crypto dependencies** (default build)
```bash
# Works out of the box (no apt install gpg openssl)
cargo build --release
./target/release/vm-cli --version
```

✅ **Cross-platform builds trivial:**
```bash
# Windows (no Gpg4win needed)
cargo build --target x86_64-pc-windows-msvc

# macOS (no Homebrew openssl)
cargo build --target aarch64-apple-darwin

# Static Linux (no glibc/OpenSSL runtime)
cargo build --target x86_64-unknown-linux-musl
```

✅ **Type-safe key management:**
```rust
// Compiler prevents using wrong key
fn sign(key: &SigningKey, data: &[u8]) -> Signature;
fn verify(key: &VerifyingKey, sig: &Signature, data: &[u8]) -> Result<()>;

// Not: sign(key_id: &str, data: &[u8]) -> Result<String>
```

✅ **Testable without system state:**
```rust
#[test]
fn test_sign_verify_roundtrip() {
    let key = generate_test_key();  // In-memory, no ~/.gnupg
    let data = b"test";
    let sig = sign_detached(&key, data).unwrap();
    assert!(verify_detached(&key.public(), &sig, data).is_ok());
}
```

### Negative

⚠️ **Sequoia learning curve** (different API than GPG CLI)

⚠️ **Potential incompatibility** with ancient GPG keys (pre-v4 packets)
- Mitigation: `gpg-compat` feature enables legacy support

⚠️ **TSA certificate validation** requires careful SPKI pinning
- Mitigation: Ship known-good TSA certs, document rotation process

### Neutral

🔄 **GPG interop maintained:**
```bash
# Export Sequoia key for GPG use
vm-cli key export --armor > key.asc
gpg --import key.asc

# Import GPG key for Sequoia use
gpg --export --armor KEYID > key.asc
vm-cli key import < key.asc
```

🔄 **Migration path:**
- Phase 1: Reimplement sign/verify in Rust, keep GPG as fallback
- Phase 2: Remove GPG shell-out entirely
- Phase 3: Offer migration tool for existing GPG keyrings

---

## Covenant Alignment

### IV. PROOF-CHAIN (Rubedo)
**Preserved semantics:**
```rust
pub struct Artifact {
    pub sha256: [u8; 32],
    pub gpg_signature: Option<Vec<u8>>,      // Sequoia-generated, GPG-compatible
    pub rfc3161_token: Option<Vec<u8>>,      // x509-tsp, OpenSSL-verifiable
    pub merkle_proof: Option<MerkleProof>,
}
```

**Verification still works:**
```bash
# Extract signature from receipt
jq -r '.gpg_signature' receipt.json | base64 -d > sig.asc

# Verify with system GPG (backwards compat)
gpg --verify sig.asc artifact.tar.gz
```

### III. FEDERATION (Citrinitas)
**JCS enables deterministic merge:**
```rust
let canonical_a = serde_jcs::to_vec(&receipt_a)?;
let canonical_b = serde_jcs::to_vec(&receipt_b)?;
let merged = merge_receipts(&canonical_a, &canonical_b)?;
assert_eq!(serde_jcs::to_vec(&merged)?, expected_canonical);
```

---

## Security Considerations

### 1. Key Material Protection
**Sequoia keys in memory:**
```rust
use zeroize::Zeroize;

pub struct SigningKey {
    cert: openpgp::Cert,
    #[zeroize(drop)]  // Clear on drop
    key: openpgp::packet::Key<openpgp::packet::key::SecretParts, _>,
}
```

### 2. TSA Certificate Pinning
**SPKI pinning (rustls):**
```rust
let mut root_store = rustls::RootCertStore::empty();
root_store.add(&freetsa_cert)?;  // Pinned cert

let config = rustls::ClientConfig::builder()
    .with_root_certificates(root_store)
    .with_no_client_auth();
```

### 3. Dual-TSA Verification
**Any-pass logic (either TSA valid = accept):**
```rust
let public_ok = verify_tsa(&token, &public_tsa_cert).is_ok();
let enterprise_ok = verify_tsa(&token, &enterprise_tsa_cert).is_ok();
if !public_ok && !enterprise_ok {
    return Err("Both TSAs failed verification");
}
```

---

## Alternatives Considered

### 1. **Keep shelling to GPG/OpenSSL**
- ❌ System dependency hell
- ❌ No type safety
- ❌ Hard to test
- ❌ Cross-platform pain

### 2. **Use OpenSSL via openssl-sys**
- ⚠️ Better than shelling, but still C bindings
- ❌ Windows builds painful (vcpkg required)
- ❌ Memory safety relies on correct FFI usage

### 3. **Use GnuPG Made Easy (GPGME)**
- ⚠️ C library, needs system GPG anyway
- ❌ Doesn't solve portability problem

---

## Dependencies

**vm-crypto/Cargo.toml:**
```toml
[dependencies]
sequoia-openpgp = "1.21"
x509-tsp = "0.3"
rustls = { version = "0.23", optional = true }
aws-lc-rs = { version = "1", optional = true }
openssl = { version = "0.10", features = ["vendored"], optional = true }
reqwest = { version = "0.12", features = ["blocking", "rustls-tls"], default-features = false }
serde_jcs = "0.1"
sha2 = "0.10"
zeroize = "1"
```

---

## Testing Strategy

### Unit tests (crypto primitives)
```rust
#[test]
fn sign_verify_roundtrip() { /* ... */ }

#[test]
fn jcs_stability() {
    let r1 = Receipt { component: "foo", version: "1.0", sha256: [0u8; 32] };
    let c1 = serde_jcs::to_vec(&r1).unwrap();
    let r2: Receipt = serde_json::from_slice(&c1).unwrap();
    let c2 = serde_jcs::to_vec(&r2).unwrap();
    assert_eq!(c1, c2);
}
```

### Integration tests (TSA end-to-end)
```rust
#[test]
#[ignore]  // Requires network
fn test_freetsa_timestamp() {
    let hash = [0u8; 32];
    let token = request_timestamp("https://freetsa.org/tsr", &hash).unwrap();
    verify_timestamp(&token, &hash).unwrap();
}
```

### Property tests (JCS determinism)
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn jcs_is_deterministic(r in any::<Receipt>()) {
        let c1 = serde_jcs::to_vec(&r).unwrap();
        let c2 = serde_jcs::to_vec(&r).unwrap();
        prop_assert_eq!(c1, c2);
    }
}
```

### Fuzz targets (signature parsing)
```rust
// fuzz/fuzz_targets/parse_signature.rs
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let _ = sequoia_openpgp::packet::Signature::from_bytes(data);
});
```

---

## Migration Checklist

- [ ] Port `ops/bin/deploy-receipt` signing to Sequoia
- [ ] Port `ops/bin/remembrancer verify-audit` to x509-tsp
- [ ] Add `vm-cli key generate` command
- [ ] Add `vm-cli key import/export` (GPG compat)
- [ ] Update CI to use Rust crypto (remove `gpg` from `apt-get`)
- [ ] Document SPKI pinning for TSAs
- [ ] Ship known-good TSA certificates in `vm-crypto/certs/`

---

## References

- [Sequoia OpenPGP](https://sequoia-pgp.org/)
- [RustCrypto: x509-tsp](https://github.com/RustCrypto/formats/tree/master/tsp)
- [rustls](https://github.com/rustls/rustls)
- [RFC 4880: OpenPGP](https://datatracker.ietf.org/doc/html/rfc4880)
- [RFC 3161: Time-Stamp Protocol](https://datatracker.ietf.org/doc/html/rfc3161)
- [RFC 8785: JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)

---

**Decision:** PROCEED with Sequoia + x509-tsp + rustls
**Next:** ADR-0003 (Storage & Indexes)

---

🜄 **Albedo:** The purification begins. Pure cryptographic light.
