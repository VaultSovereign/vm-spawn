use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artifact {
    pub sha256: [u8; 32],
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gpg_signature: Option<Vec<u8>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rfc3161_token: Option<Vec<u8>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub merkle_proof: Option<crate::merkle::MerkleProof>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Receipt {
    pub id: String,
    pub component: String,
    pub version: String,
    pub artifact: Artifact,
    pub timestamp_utc: String,
    #[serde(default)]
    pub context: serde_json::Value,
}
impl Receipt {
    pub fn make_id(component: &str, version: &str, sha: &[u8; 32]) -> String {
        format!("{component}@{version}:{}", hex::encode(&sha[..4]))
    }
}
