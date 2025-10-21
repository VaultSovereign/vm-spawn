# ADR-0004: Canonicalization & Merge

**Status:** PROPOSED
**Date:** 2025-10-21
**Deciders:** Sovereign + DAO (if governance active)
**Context:** VaultMesh v5.0 evolution — Deterministic federation substrate

---

## Context

VaultMesh's federation layer (Covenant III: Citrinitas) requires **deterministic merge** of receipts across nodes. Without canonicalization, identical semantic content produces different byte representations:

```json
// Node A
{"component":"oracle","version":"1.0"}

// Node B (different whitespace, key order)
{
  "version": "1.0",
  "component": "oracle"
}
```

**Same semantic content, different SHA-256 hashes → Merkle roots diverge.**

**Requirements:**
- ✅ **Deterministic serialization** (same receipt → same bytes, always)
- ✅ **Round-trip stable** (parse → canonicalize → parse = identical)
- ✅ **RFC standard** (not ad-hoc)
- ✅ **Merkle-safe** (content-addressed receipts)
- ✅ **Federation-ready** (libp2p gossip, CRDT merge)

---

## Decision

**Adopt JSON Canonicalization Scheme (JCS, RFC 8785) for all receipt serialization.**

**Implementation:**
```rust
use serde_jcs;

#[derive(Serialize, Deserialize)]
pub struct Receipt {
    pub component: String,
    pub version: String,
    pub sha256: [u8; 32],
    pub timestamp_utc: String,
}

// Canonical serialization (deterministic bytes)
pub fn to_canonical(receipt: &Receipt) -> Result<Vec<u8>> {
    Ok(serde_jcs::to_vec(receipt)?)
}

// Content-addressed ID (SHA-256 of canonical JSON)
pub fn receipt_id(receipt: &Receipt) -> [u8; 32] {
    let canonical = to_canonical(receipt).unwrap();
    sha256(&canonical)
}
```

**JCS guarantees:**
1. **Object keys sorted lexicographically**
2. **No whitespace** (compact)
3. **Unicode normalization** (NFC)
4. **Number formatting** (no leading zeros, no `.0` for integers)

**Example:**
```rust
let receipt = Receipt {
    component: "oracle".into(),
    version: "1.0".into(),
    sha256: [0xab; 32],
    timestamp_utc: "2025-10-21T12:00:00Z".into(),
};

let canonical = serde_jcs::to_vec(&receipt)?;
// Output (always): {"component":"oracle","sha256":"ababababab...","timestamp_utc":"2025-10-21T12:00:00Z","version":"1.0"}
//                  ↑ Keys sorted: component, sha256, timestamp_utc, version
```

---

## Rationale

### Why JCS (RFC 8785)?

**Comparison:**

| Approach | Standard | Deterministic | Round-trip | Complexity |
|----------|----------|--------------|------------|------------|
| **JCS (RFC 8785)** | ✅ RFC | ✅ Yes | ✅ Yes | Low |
| `jq -S` | ❌ Ad-hoc | ⚠️ Mostly | ⚠️ Depends | Medium |
| CBOR | ✅ RFC 8949 | ✅ Yes | ✅ Yes | High |
| Protobuf | ❌ Google | ⚠️ With canonicalize | ❌ No | High |
| Bare JSON | ❌ No | ❌ No | ✅ Yes | Low |

**JCS wins on:**
- ✅ **RFC standard:** Not ad-hoc (unlike `jq --sort-keys`)
- ✅ **JSON-native:** No binary formats (human-readable)
- ✅ **Simple:** Single function call (`serde_jcs::to_vec`)
- ✅ **Rust ecosystem:** `serde_jcs` integrates with `serde`

### Why NOT alternatives?

#### 1. `jq --sort-keys` (current v4.1 approach)
```bash
# v4.1 canonicalization
jq -S -c . receipt.json
```
**Problems:**
- ❌ **Not standardized:** `jq` implementation-specific
- ❌ **Whitespace handling varies:** Different `jq` versions
- ❌ **Number formatting inconsistent:** `1.0` vs `1`
- ❌ **Unicode normalization unspecified**

#### 2. CBOR (RFC 8949)
**Advantages:**
- ✅ Deterministic (with canonical mode)
- ✅ Binary-efficient

**Disadvantages:**
- ❌ **Not human-readable:** Binary format
- ❌ **Ecosystem smaller:** Fewer tools
- ❌ **Migration cost:** Existing JSON receipts need conversion

**Verdict:** CBOR better for high-throughput, but VaultMesh values human-readability (audit transparency).

#### 3. Protobuf
**Disadvantages:**
- ❌ **No built-in canonicalization:** Must implement manually
- ❌ **Schema required:** `.proto` files add complexity
- ❌ **Not round-trip stable:** Binary encoding != JSON

---

## Implementation

### Core Library (`vm-core/src/canonical.rs`)

```rust
use serde::{Serialize, Deserialize};
use sha2::{Sha256, Digest};

/// Serialize to canonical JSON (JCS, RFC 8785)
pub fn to_canonical<T: Serialize>(value: &T) -> anyhow::Result<Vec<u8>> {
    Ok(serde_jcs::to_vec(value)?)
}

/// Deserialize from canonical JSON
pub fn from_canonical<T: for<'a> Deserialize<'a>>(bytes: &[u8]) -> anyhow::Result<T> {
    Ok(serde_json::from_slice(bytes)?)
}

/// Content-addressed ID (SHA-256 of canonical JSON)
pub fn content_id<T: Serialize>(value: &T) -> anyhow::Result<[u8; 32]> {
    let canonical = to_canonical(value)?;
    let mut hasher = Sha256::new();
    hasher.update(&canonical);
    Ok(hasher.finalize().into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::Serialize;

    #[derive(Serialize, Deserialize, PartialEq, Debug)]
    struct TestReceipt {
        component: String,
        version: String,
    }

    #[test]
    fn test_canonical_deterministic() {
        let r = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let c1 = to_canonical(&r).unwrap();
        let c2 = to_canonical(&r).unwrap();
        assert_eq!(c1, c2);
    }

    #[test]
    fn test_canonical_round_trip() {
        let r1 = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let canonical = to_canonical(&r1).unwrap();
        let r2: TestReceipt = from_canonical(&canonical).unwrap();
        assert_eq!(r1, r2);
    }

    #[test]
    fn test_content_id_stable() {
        let r = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let id1 = content_id(&r).unwrap();
        let id2 = content_id(&r).unwrap();
        assert_eq!(id1, id2);
    }

    #[test]
    fn test_key_order_sorted() {
        let r = TestReceipt {
            version: "1.0".into(),  // Intentionally wrong order
            component: "oracle".into(),
        };
        let canonical = to_canonical(&r).unwrap();
        let json_str = String::from_utf8(canonical).unwrap();
        // JCS sorts keys: component before version
        assert!(json_str.starts_with(r#"{"component":"oracle","version":"1.0"}"#));
    }
}
```

---

## Consequences

### Positive

✅ **Merkle roots stable across nodes:**
```rust
// Node A
let receipt_a = Receipt { component: "oracle", version: "1.0", ... };
let id_a = content_id(&receipt_a)?;

// Node B (same semantic data)
let receipt_b = Receipt { component: "oracle", version: "1.0", ... };
let id_b = content_id(&receipt_b)?;

assert_eq!(id_a, id_b);  // Merkle roots converge
```

✅ **Content-addressed storage:**
```rust
pub fn insert_receipt(store: &Store, receipt: &Receipt) -> Result<()> {
    let id = content_id(receipt)?;
    if store.get(&id)?.is_some() {
        return Ok(());  // Already stored (deduplication automatic)
    }
    store.put(&id, to_canonical(receipt)?)?;
    Ok(())
}
```

✅ **Federation merge deterministic:**
```rust
pub fn merge_receipts(a: &Receipt, b: &Receipt) -> Result<Receipt> {
    let canonical_a = to_canonical(a)?;
    let canonical_b = to_canonical(b)?;

    if canonical_a == canonical_b {
        return Ok(a.clone());  // Identical, no merge needed
    }

    // Three-way merge (future: CRDT)
    let merged = three_way_merge(&canonical_a, &canonical_b)?;
    from_canonical(&merged)
}
```

✅ **Human-readable diffs:**
```bash
# Compare receipts across nodes
diff <(vm-cli export --node A --canonical) \
     <(vm-cli export --node B --canonical)
```

### Negative

⚠️ **JSON overhead** vs binary formats (CBOR ~30% smaller)
- Mitigation: VaultMesh receipts are small (<10 KB), negligible

⚠️ **Canonicalization cost** (parse + sort keys + serialize)
- Mitigation: ~1 ms per receipt, acceptable for CLI tool

### Neutral

🔄 **Migration from v4.1:**
```bash
# Re-canonicalize existing receipts
for f in ops/receipts/deploy/*.json; do
  vm-cli canonicalize < "$f" > "${f}.canonical"
  mv "${f}.canonical" "$f"
done
```

🔄 **Verification:**
```bash
# Verify all receipts are canonical
for f in ops/receipts/deploy/*.json; do
  vm-cli verify-canonical "$f" || echo "ERROR: $f not canonical"
done
```

---

## Covenant Alignment

### III. FEDERATION (Citrinitas)
**Deterministic merge enabled:**
```rust
// Receipt IDs identical across nodes → Merkle roots converge
let id = content_id(&receipt)?;  // SHA-256 of canonical JSON
```

### I. INTEGRITY (Nigredo)
**Tamper detection:**
```rust
pub fn verify_receipt(receipt: &Receipt, expected_id: &[u8; 32]) -> Result<()> {
    let actual_id = content_id(receipt)?;
    if actual_id != *expected_id {
        return Err(anyhow!("Receipt tampered! ID mismatch"));
    }
    Ok(())
}
```

### II. REPRODUCIBILITY (Albedo)
**Deterministic builds:**
```rust
// Same receipt → same bytes → same Merkle root (always)
assert_eq!(to_canonical(&receipt1)?, to_canonical(&receipt1)?);
```

---

## Security Considerations

### 1. Hash Collision Resistance
**SHA-256 provides 128-bit collision resistance** (birthday bound).
- ✅ Sufficient for VaultMesh (receipts non-adversarial)
- 🔄 Future: Upgrade to SHA-3 if needed

### 2. Unicode Normalization
**JCS applies NFC (Normalization Form C):**
```rust
// These are different Unicode sequences, same visual:
let a = "café";  // U+0063 U+0061 U+0066 U+00E9
let b = "café";  // U+0063 U+0061 U+0066 U+0065 U+0301

// JCS normalizes both to NFC → same canonical JSON
assert_eq!(to_canonical(&a)?, to_canonical(&b)?);
```

### 3. Number Precision
**JCS uses IEEE 754 double precision:**
```rust
// Integers exact up to 2^53
let n1 = 9007199254740991i64;  // 2^53 - 1
let n2 = 9007199254740992i64;  // 2^53

assert_eq!(to_canonical(&n1)?, to_canonical(&n1)?);  // Safe
// Beyond 2^53, use strings for exact representation
```

**VaultMesh mitigation:**
- Timestamps: Use ISO 8601 strings (`"2025-10-21T12:00:00Z"`)
- Hashes: Use hex strings (`"abcdef..."`)
- Counts: u32 sufficient (max 4 billion receipts)

---

## Testing Strategy

### Unit tests (determinism)
```rust
#[test]
fn canonical_is_deterministic() {
    let r = Receipt { component: "test", version: "1.0", ... };
    let c1 = to_canonical(&r).unwrap();
    let c2 = to_canonical(&r).unwrap();
    assert_eq!(c1, c2);
}
```

### Property tests (round-trip stability)
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn canonical_round_trip(r in any::<Receipt>()) {
        let canonical = to_canonical(&r).unwrap();
        let decoded: Receipt = from_canonical(&canonical).unwrap();
        let recanonical = to_canonical(&decoded).unwrap();
        prop_assert_eq!(canonical, recanonical);
    }
}
```

### Integration tests (Merkle convergence)
```rust
#[test]
fn merkle_roots_converge() {
    // Node A inserts receipts in order [r1, r2, r3]
    let mut store_a = MemStore::new();
    store_a.insert(&r1).unwrap();
    store_a.insert(&r2).unwrap();
    store_a.insert(&r3).unwrap();
    let root_a = compute_merkle_root(&store_a).unwrap();

    // Node B inserts same receipts in different order [r3, r1, r2]
    let mut store_b = MemStore::new();
    store_b.insert(&r3).unwrap();
    store_b.insert(&r1).unwrap();
    store_b.insert(&r2).unwrap();
    let root_b = compute_merkle_root(&store_b).unwrap();

    assert_eq!(root_a, root_b);  // Roots converge (content-addressed)
}
```

### Fuzz tests (malformed JSON)
```rust
// fuzz/fuzz_targets/canonical_parse.rs
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // Should not panic on malformed input
    let _ = serde_json::from_slice::<Receipt>(data);
});
```

---

## Alternatives Considered

### 1. **Continue with `jq -S`**
- ❌ Not standardized
- ❌ Implementation-specific
- ❌ Hard to test (shell dependency)

### 2. **CBOR (RFC 8949)**
- ✅ Deterministic, binary-efficient
- ❌ Not human-readable (audit opacity)
- ❌ Ecosystem smaller than JSON

### 3. **Protobuf**
- ❌ No built-in canonicalization
- ❌ Schema complexity (`.proto` files)
- ❌ Not round-trip stable with JSON

### 4. **Custom JSON serializer**
- ❌ Reinventing the wheel
- ❌ Difficult to prove correctness
- ❌ No standard (interop problems)

---

## Migration from v4.1

**Step 1: Validate existing receipts**
```bash
# Check if receipts are already canonical
for f in ops/receipts/deploy/*.json; do
  if ! jq -e -S -c . "$f" | diff - <(cat "$f") > /dev/null; then
    echo "Non-canonical: $f"
  fi
done
```

**Step 2: Re-canonicalize**
```bash
vm-cli migrate-v4 --in ops/receipts/deploy --out receipts-canonical/
```

**Step 3: Verify Merkle root**
```bash
OLD_ROOT=$(awk '/Current Root:/{print $3}' docs/REMEMBRANCER.md | tr -d '`')
NEW_ROOT=$(vm-cli merkle-root --from receipts-canonical/)

if [ "$OLD_ROOT" != "$NEW_ROOT" ]; then
  echo "ERROR: Merkle root changed after canonicalization!"
  echo "This indicates data corruption or implementation bug."
  exit 1
fi
```

---

## Dependencies

**vm-core/Cargo.toml:**
```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_jcs = "0.1"
sha2 = "0.10"
anyhow = "1"

[dev-dependencies]
proptest = "1"
```

---

## References

- [RFC 8785: JSON Canonicalization Scheme (JCS)](https://datatracker.ietf.org/doc/html/rfc8785)
- [serde_jcs crate](https://crates.io/crates/serde_jcs)
- [Content Addressing](https://en.wikipedia.org/wiki/Content-addressable_storage)
- [Merkle Tree](https://en.wikipedia.org/wiki/Merkle_tree)
- [Unicode Normalization](https://unicode.org/reports/tr15/)

---

**Decision:** PROCEED with JCS (RFC 8785)
**Next:** Workspace scaffold + PoC implementation

---

🜄 **Rubedo:** The reddening. Federation substrate crystallizes into form.
