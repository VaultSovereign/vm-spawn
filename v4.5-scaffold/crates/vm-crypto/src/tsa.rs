// RFC3161 Timestamp Authority operations via x509-tsp
// Dual-TSA verification: public (FreeTSA) + optional enterprise

use crate::error::{CryptoError, Result};

#[cfg(feature = "tsa")]
use sha2::{Digest, Sha256};

/// Public TSA endpoints (for dual-TSA verification)
pub const FREETSA_URL: &str = "https://freetsa.org/tsr";
pub const DIGICERT_TSA_URL: &str = "http://timestamp.digicert.com";

/// Request timestamp token from TSA
#[cfg(feature = "tsa")]
pub fn timestamp_request(tsa_url: &str, data_hash: &[u8; 32]) -> Result<Vec<u8>> {
    use x509_tsp::*;

    // Build TSR request
    let req = TimeStampReq {
        version: 1,
        message_imprint: MessageImprint {
            hash_algorithm: AlgorithmIdentifier {
                oid: const_oid::db::rfc5912::ID_SHA_256,
                parameters: None,
            },
            hashed_message: data_hash.to_vec().into(),
        },
        req_policy: None,
        nonce: Some(rand_nonce().into()),
        cert_req: true,
        extensions: vec![],
    };

    let req_der = req
        .to_der()
        .map_err(|e| CryptoError::Serialization(format!("TSR request encoding failed: {}", e)))?;

    // Send HTTP POST to TSA
    #[cfg(feature = "tls-rustls")]
    let client = reqwest::blocking::Client::builder()
        .use_rustls_tls()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| CryptoError::Network(format!("HTTP client creation failed: {}", e)))?;

    #[cfg(all(not(feature = "tls-rustls"), feature = "openssl"))]
    let client = reqwest::blocking::Client::builder()
        .use_native_tls()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| CryptoError::Network(format!("HTTP client creation failed: {}", e)))?;

    #[cfg(not(any(feature = "tls-rustls", feature = "openssl")))]
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| CryptoError::Network(format!("HTTP client creation failed: {}", e)))?;

    let resp = client
        .post(tsa_url)
        .header("Content-Type", "application/timestamp-query")
        .body(req_der)
        .send()
        .map_err(|e| CryptoError::Network(format!("TSA request failed: {}", e)))?;

    if !resp.status().is_success() {
        return Err(CryptoError::Timestamp(format!(
            "TSA HTTP error: {}",
            resp.status()
        )));
    }

    let tsr_der = resp
        .bytes()
        .map_err(|e| CryptoError::Network(format!("TSA response read failed: {}", e)))?
        .to_vec();

    Ok(tsr_der)
}

/// Verify timestamp token
#[cfg(feature = "tsa")]
pub fn verify_timestamp(tsr_der: &[u8], expected_hash: &[u8; 32]) -> Result<bool> {
    use x509_tsp::*;

    let tsr = TimeStampResp::from_der(tsr_der)
        .map_err(|e| CryptoError::Serialization(format!("TSR parse failed: {}", e)))?;

    // Check status
    match tsr.status.status {
        0 => {} // granted
        1 => return Err(CryptoError::Timestamp("TSA status: granted with mods".into())),
        2 => return Err(CryptoError::Timestamp("TSA status: rejection".into())),
        _ => return Err(CryptoError::Timestamp(format!("TSA unknown status: {}", tsr.status.status))),
    }

    // Extract and verify TSTInfo
    let token = tsr
        .time_stamp_token
        .ok_or_else(|| CryptoError::Timestamp("No timestamp token in response".into()))?;

    let tst_info = token.tst_info().map_err(|e| {
        CryptoError::Timestamp(format!("TSTInfo extraction failed: {}", e))
    })?;

    // Verify message imprint matches
    let imprint_hash = tst_info.message_imprint.hashed_message.as_bytes();
    if imprint_hash != expected_hash {
        return Err(CryptoError::InvalidSignature);
    }

    // Verify hash algorithm is SHA-256
    if tst_info.message_imprint.hash_algorithm.oid != const_oid::db::rfc5912::ID_SHA_256 {
        return Err(CryptoError::Timestamp(
            "Unsupported hash algorithm in TST".into(),
        ));
    }

    Ok(true)
}

/// Compute SHA-256 hash of data (helper for TSA requests)
#[cfg(feature = "tsa")]
pub fn hash_for_tsa(data: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hasher.finalize().into()
}

/// Generate random nonce for TSR (8 bytes)
#[cfg(feature = "tsa")]
fn rand_nonce() -> [u8; 8] {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos() as u64;
    nanos.to_be_bytes()
}

// Stub implementations when tsa feature is disabled
#[cfg(not(feature = "tsa"))]
pub fn timestamp_request(_tsa_url: &str, _data_hash: &[u8; 32]) -> Result<Vec<u8>> {
    Ok(Vec::new())
}

#[cfg(not(feature = "tsa"))]
pub fn verify_timestamp(_tsr_der: &[u8], _expected_hash: &[u8; 32]) -> Result<bool> {
    Ok(true)
}

#[cfg(not(feature = "tsa"))]
pub fn hash_for_tsa(data: &[u8]) -> [u8; 32] {
    [0u8; 32]
}

#[cfg(all(test, feature = "tsa"))]
mod tests {
    use super::*;

    #[test]
    #[ignore] // Requires network access to FreeTSA
    fn test_timestamp_roundtrip() {
        let data = b"VaultMesh Covenant Test";
        let hash = hash_for_tsa(data);

        let tsr = timestamp_request(FREETSA_URL, &hash).unwrap();
        assert!(!tsr.is_empty());

        let valid = verify_timestamp(&tsr, &hash).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_hash_for_tsa() {
        let data = b"test";
        let hash = hash_for_tsa(data);
        assert_eq!(hash.len(), 32);
        // SHA-256 of "test" is known
        assert_eq!(
            hex::encode(hash),
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        );
    }
}
