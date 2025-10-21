//! Canonical JSON serialization (JCS, RFC 8785)

use serde::{Serialize, de::DeserializeOwned};
use sha2::{Sha256, Digest};

/// Serialize to canonical JSON (JCS, RFC 8785)
///
/// JCS guarantees:
/// - Object keys sorted lexicographically
/// - No whitespace (compact)
/// - Unicode normalization (NFC)
/// - Deterministic number formatting
pub fn to_canonical<T: Serialize>(value: &T) -> anyhow::Result<Vec<u8>> {
    Ok(serde_jcs::to_vec(value)?)
}

/// Deserialize from canonical JSON
pub fn from_canonical<T: DeserializeOwned>(bytes: &[u8]) -> anyhow::Result<T> {
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
    use serde::{Serialize, Deserialize};

    #[derive(Serialize, Deserialize, PartialEq, Debug)]
    struct TestData {
        component: String,
        version: String,
    }

    #[test]
    fn test_canonical_deterministic() {
        let data = TestData {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let c1 = to_canonical(&data).unwrap();
        let c2 = to_canonical(&data).unwrap();
        assert_eq!(c1, c2);
    }

    #[test]
    fn test_canonical_round_trip() {
        let data = TestData {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let canonical = to_canonical(&data).unwrap();
        let decoded: TestData = from_canonical(&canonical).unwrap();
        assert_eq!(data, decoded);

        // Re-canonicalize should produce identical bytes
        let recanonical = to_canonical(&decoded).unwrap();
        assert_eq!(canonical, recanonical);
    }

    #[test]
    fn test_content_id_stable() {
        let data = TestData {
            component: "oracle".into(),
            version: "1.0".into(),
        };
        let id1 = content_id(&data).unwrap();
        let id2 = content_id(&data).unwrap();
        assert_eq!(id1, id2);
    }

    #[test]
    fn test_key_order_sorted() {
        // Intentionally create struct with "wrong" field order
        #[derive(Serialize)]
        struct Unsorted {
            z_last: String,
            a_first: String,
        }

        let data = Unsorted {
            z_last: "last".into(),
            a_first: "first".into(),
        };

        let canonical = to_canonical(&data).unwrap();
        let json_str = String::from_utf8(canonical).unwrap();

        // JCS should sort keys: a_first before z_last
        assert!(json_str.starts_with(r#"{"a_first":"first","z_last":"last"}"#));
    }
}

#[cfg(test)]
mod proptests {
    use super::*;
    use proptest::prelude::*;

    #[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
    struct ArbitraryReceipt {
        component: String,
        version: String,
        count: u32,
    }

    impl Arbitrary for ArbitraryReceipt {
        type Parameters = ();
        type Strategy = BoxedStrategy<Self>;

        fn arbitrary_with(_: Self::Parameters) -> Self::Strategy {
            (
                "[a-z]{3,10}",
                "[0-9]{1,2}\\.[0-9]{1,2}",
                any::<u32>(),
            )
                .prop_map(|(component, version, count)| ArbitraryReceipt {
                    component,
                    version,
                    count,
                })
                .boxed()
        }
    }

    proptest! {
        #[test]
        fn canonical_is_deterministic(r in any::<ArbitraryReceipt>()) {
            let c1 = to_canonical(&r).unwrap();
            let c2 = to_canonical(&r).unwrap();
            prop_assert_eq!(c1, c2);
        }

        #[test]
        fn canonical_round_trip_stable(r in any::<ArbitraryReceipt>()) {
            let canonical = to_canonical(&r).unwrap();
            let decoded: ArbitraryReceipt = from_canonical(&canonical).unwrap();
            let recanonical = to_canonical(&decoded).unwrap();
            prop_assert_eq!(canonical, recanonical);
        }

        #[test]
        fn content_id_deterministic(r in any::<ArbitraryReceipt>()) {
            let id1 = content_id(&r).unwrap();
            let id2 = content_id(&r).unwrap();
            prop_assert_eq!(id1, id2);
        }
    }
}
