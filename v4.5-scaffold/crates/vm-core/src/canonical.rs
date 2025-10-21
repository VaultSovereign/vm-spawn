// JSON Canonicalization Scheme (RFC 8785)
// Ensures deterministic serialization for Merkle trees and federation

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Serialize to JCS canonical JSON bytes
pub fn to_jcs_bytes<T: Serialize>(v: &T) -> Result<Vec<u8>> {
    Ok(serde_jcs::to_vec(v)?)
}

/// Deserialize from canonical JSON
pub fn from_jcs_bytes<'a, T: Deserialize<'a>>(bytes: &'a [u8]) -> Result<T> {
    Ok(serde_json::from_slice(bytes)?)
}

/// Compute content ID (SHA-256 of canonical JSON)
pub fn content_id<T: Serialize>(v: &T) -> Result<[u8; 32]> {
    use sha2::{Digest, Sha256};
    let canonical = to_jcs_bytes(v)?;
    let mut hasher = Sha256::new();
    hasher.update(&canonical);
    Ok(hasher.finalize().into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Serialize, Deserialize, Debug, PartialEq, Clone)]
    struct TestReceipt {
        component: String,
        version: String,
        sha256: String,
    }

    #[test]
    fn test_jcs_deterministic() {
        let r = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
            sha256: "abcd1234".into(),
        };
        let c1 = to_jcs_bytes(&r).unwrap();
        let c2 = to_jcs_bytes(&r).unwrap();
        assert_eq!(c1, c2);
    }

    #[test]
    fn test_jcs_round_trip() {
        let r1 = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
            sha256: "abcd1234".into(),
        };
        let canonical = to_jcs_bytes(&r1).unwrap();
        let r2: TestReceipt = from_jcs_bytes(&canonical).unwrap();
        assert_eq!(r1, r2);

        // Second canonicalization should be identical
        let canonical2 = to_jcs_bytes(&r2).unwrap();
        assert_eq!(canonical, canonical2);
    }

    #[test]
    fn test_content_id_stable() {
        let r = TestReceipt {
            component: "oracle".into(),
            version: "1.0".into(),
            sha256: "abcd1234".into(),
        };
        let id1 = content_id(&r).unwrap();
        let id2 = content_id(&r).unwrap();
        assert_eq!(id1, id2);
    }

    #[test]
    fn test_key_order_sorted() {
        use serde_json::json;
        // Create object with intentionally wrong key order
        let obj = json!({"z": 3, "a": 1, "m": 2});
        let canonical = to_jcs_bytes(&obj).unwrap();
        let s = String::from_utf8(canonical).unwrap();
        // JCS sorts keys: a, m, z
        assert!(s.starts_with(r#"{"a":"#));
    }
}

#[cfg(test)]
mod proptests {
    use super::*;
    use proptest::prelude::*;

    #[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
    struct PropReceipt {
        component: String,
        version: String,
        count: u32,
    }

    // Generate arbitrary PropReceipt for property testing
    fn arb_receipt() -> impl Strategy<Value = PropReceipt> {
        (
            "[a-z]{3,10}",
            "[0-9]{1,3}\\.[0-9]{1,3}",
            0u32..1000u32,
        )
            .prop_map(|(c, v, n)| PropReceipt {
                component: c,
                version: v,
                count: n,
            })
    }

    proptest! {
        #[test]
        fn proptest_jcs_is_deterministic(r in arb_receipt()) {
            let c1 = to_jcs_bytes(&r).unwrap();
            let c2 = to_jcs_bytes(&r).unwrap();
            prop_assert_eq!(c1, c2);
        }

        #[test]
        fn proptest_jcs_round_trip_stable(r in arb_receipt()) {
            let c1 = to_jcs_bytes(&r).unwrap();
            let decoded: PropReceipt = from_jcs_bytes(&c1).unwrap();
            let c2 = to_jcs_bytes(&decoded).unwrap();
            prop_assert_eq!(c1, c2, "JCS round-trip not stable");
            prop_assert_eq!(r, decoded, "Decoded value differs");
        }

        #[test]
        fn proptest_content_id_stable(r in arb_receipt()) {
            let id1 = content_id(&r).unwrap();
            let id2 = content_id(&r).unwrap();
            prop_assert_eq!(id1, id2);
        }
    }
}
