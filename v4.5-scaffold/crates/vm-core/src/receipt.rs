//! Receipt types for VaultMesh deployments

use serde::{Deserialize, Serialize};

/// Receipt ID (SHA-256 of canonical JSON)
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ReceiptId(pub [u8; 32]);

impl ReceiptId {
    pub fn as_hex(&self) -> String {
        hex::encode(self.0)
    }

    pub fn from_hex(s: &str) -> anyhow::Result<Self> {
        let bytes = hex::decode(s)?;
        if bytes.len() != 32 {
            anyhow::bail!("Invalid receipt ID: expected 32 bytes, got {}", bytes.len());
        }
        let mut arr = [0u8; 32];
        arr.copy_from_slice(&bytes);
        Ok(Self(arr))
    }
}

/// Cryptographic artifact (tarball + signatures + timestamps + merkle proof)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Artifact {
    /// SHA-256 of artifact bytes
    pub sha256: [u8; 32],

    /// GPG detached signature (armored, optional)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpg_signature: Option<Vec<u8>>,

    /// RFC3161 timestamp token (DER-encoded, optional)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rfc3161_token: Option<Vec<u8>>,

    /// Merkle proof (position in tree)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub merkle_proof: Option<Vec<[u8; 32]>>,
}

/// Deployment receipt (canonical record of a deployment event)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Receipt {
    /// Component name (e.g., "oracle", "core-api")
    pub component: String,

    /// Version (e.g., "1.0.0", "v4.1-genesis")
    pub version: String,

    /// Deployment target (e.g., "production", "staging")
    pub target: String,

    /// Timestamp (ISO 8601 UTC)
    pub timestamp_utc: String,

    /// Deployment success flag
    pub ok: bool,

    /// Cryptographic artifact
    pub artifact: Artifact,

    /// Optional context (logs, environment, etc.)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<serde_json::Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_receipt_roundtrip() {
        let receipt = Receipt {
            component: "test".into(),
            version: "1.0".into(),
            target: "production".into(),
            timestamp_utc: "2025-10-21T12:00:00Z".into(),
            ok: true,
            artifact: Artifact {
                sha256: [0xab; 32],
                gpg_signature: None,
                rfc3161_token: None,
                merkle_proof: None,
            },
            context: None,
        };

        let json = serde_json::to_string(&receipt).unwrap();
        let decoded: Receipt = serde_json::from_str(&json).unwrap();
        assert_eq!(receipt, decoded);
    }

    #[test]
    fn test_receipt_id_hex() {
        let id = ReceiptId([0xab; 32]);
        let hex = id.as_hex();
        assert_eq!(hex.len(), 64);
        let decoded = ReceiptId::from_hex(&hex).unwrap();
        assert_eq!(id, decoded);
    }
}
