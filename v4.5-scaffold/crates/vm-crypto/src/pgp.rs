// OpenPGP operations via Sequoia-PGP
// Implements detached signing/verification for VaultMesh receipts

#[cfg(feature = "pgp")]
use sequoia_openpgp as openpgp;

#[cfg(feature = "pgp")]
use openpgp::{
    Cert, KeyHandle, armor,
    cert::CertBuilder,
    crypto::Password,
    parse::{Parse, stream::*},
    policy::StandardPolicy,
    serialize::{Marshal, stream::*},
    types::HashAlgorithm,
};

#[cfg(feature = "pgp")]
use crate::error::CryptoError;
use crate::error::Result;
#[cfg(feature = "pgp")]
use anyhow::anyhow;
#[cfg(feature = "pgp")]
use std::io::{Read, Write};
#[cfg(feature = "pgp")]
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

/// Sign data with detached signature (armored)
#[cfg(feature = "pgp")]
pub fn sign_detached(cert: &Cert, password: Option<&str>, data: &[u8]) -> Result<Vec<u8>> {
    let policy = StandardPolicy::new();

    // Find signing-capable key
    let key = cert
        .keys()
        .secret()
        .with_policy(&policy, None)
        .supported()
        .alive()
        .revoked(false)
        .for_signing()
        .next()
        .ok_or_else(|| CryptoError::KeyNotFound("No signing key found".into()))?
        .key()
        .clone();

    let key = match password {
        Some(pwd) => key
            .decrypt_secret(&Password::from(pwd))
            .map_err(|e| CryptoError::Pgp(format!("Key decryption failed: {}", e)))?,
        None => key,
    };

    let keypair = key
        .into_keypair()
        .map_err(|e| CryptoError::Pgp(format!("Keypair creation failed: {}", e)))?;

    // Create detached signature
    let mut sig_buf = Vec::new();
    {
        let message = Message::new(&mut sig_buf);
        let builder = Signer::new(message, keypair).detached();
        let builder = builder
            .hash_algo(HashAlgorithm::SHA256)
            .map_err(|e| CryptoError::Pgp(format!("Hash selection failed: {}", e)))?;
        let mut signer = builder
            .build()
            .map_err(|e| CryptoError::Pgp(format!("Signer creation failed: {}", e)))?;

        signer.write_all(data).map_err(CryptoError::Io)?;
        signer.finalize().map_err(|e| CryptoError::Pgp(format!("Finalization failed: {}", e)))?;
    }

    // Armor the signature
    let mut armored = Vec::new();
    {
        let mut writer = armor::Writer::new(&mut armored, armor::Kind::Signature)
            .map_err(|e| CryptoError::Serialization(format!("Armoring failed: {}", e)))?;
        writer.write_all(&sig_buf).map_err(CryptoError::Io)?;
        writer
            .finalize()
            .map_err(|e| CryptoError::Serialization(format!("Finalization failed: {}", e)))?;
    }

    Ok(armored)
}

/// Verify detached signature (armored or binary)
#[cfg(feature = "pgp")]
pub fn verify_detached(cert: &Cert, signature: &[u8], data: &[u8]) -> Result<bool> {
    let policy = StandardPolicy::new();

    // Normalize signature bytes (handle both armored and binary)
    let sig_bytes = if signature.starts_with(b"-----BEGIN PGP SIGNATURE-----") {
        let mut reader = armor::Reader::from_bytes(signature, None::<armor::ReaderMode>);
        let mut buf = Vec::new();
        reader.read_to_end(&mut buf).map_err(CryptoError::Io)?;
        buf
    } else {
        signature.to_vec()
    };

    // Verify using DetachedVerifier
    struct Helper<'a> {
        cert: &'a Cert,
        valid: Arc<AtomicBool>,
    }

    impl VerificationHelper for Helper<'_> {
        fn get_certs(&mut self, _ids: &[KeyHandle]) -> openpgp::Result<Vec<Cert>> {
            Ok(vec![self.cert.clone()])
        }

        fn check(&mut self, structure: MessageStructure) -> openpgp::Result<()> {
            for layer in structure {
                if let MessageLayer::SignatureGroup { results } = layer {
                    if results.iter().any(|r| r.is_ok()) {
                        self.valid.store(true, Ordering::Relaxed);
                    } else {
                        return Err(anyhow!("No valid signatures found"));
                    }
                }
            }
            Ok(())
        }
    }

    let valid = Arc::new(AtomicBool::new(false));
    let helper = Helper { cert, valid: valid.clone() };

    let mut verifier = DetachedVerifierBuilder::from_bytes(&sig_bytes)
        .map_err(|e| CryptoError::Pgp(format!("Verifier creation failed: {}", e)))?
        .with_policy(&policy, None, helper)
        .map_err(|e| CryptoError::Pgp(format!("Policy application failed: {}", e)))?;

    verifier
        .verify_bytes(data)
        .map_err(|e| CryptoError::Pgp(format!("Verification failed: {}", e)))?;

    Ok(valid.load(Ordering::Relaxed))
}

/// Generate a new test key pair (for testing only)
#[cfg(feature = "pgp")]
pub fn generate_test_key(user_id: &str) -> Result<Cert> {
    CertBuilder::new()
        .add_userid(user_id)
        .add_signing_subkey()
        .generate()
        .map_err(|e| CryptoError::Pgp(format!("Key generation failed: {}", e)))
        .map(|(cert, _)| cert)
}

/// Export certificate as armored public key
#[cfg(feature = "pgp")]
pub fn export_cert(cert: &Cert) -> Result<Vec<u8>> {
    let mut buf = Vec::new();
    {
        let mut writer = armor::Writer::new(&mut buf, armor::Kind::PublicKey)
            .map_err(|e| CryptoError::Serialization(format!("Armoring failed: {}", e)))?;
        cert.serialize(&mut writer)
            .map_err(|e| CryptoError::Serialization(format!("Serialization failed: {}", e)))?;
        writer
            .finalize()
            .map_err(|e| CryptoError::Serialization(format!("Finalization failed: {}", e)))?;
    }
    Ok(buf)
}

/// Import certificate from armored public key
#[cfg(feature = "pgp")]
pub fn import_cert(armored: &[u8]) -> Result<Cert> {
    Cert::from_bytes(armored)
        .map_err(|e| CryptoError::Pgp(format!("Certificate import failed: {}", e)))
}

// Stub implementations when pgp feature is disabled
#[cfg(not(feature = "pgp"))]
pub fn sign_detached(_cert: &(), _password: Option<&str>, _data: &[u8]) -> Result<Vec<u8>> {
    Ok(Vec::new())
}

#[cfg(not(feature = "pgp"))]
pub fn verify_detached(_cert: &(), _signature: &[u8], _data: &[u8]) -> Result<bool> {
    Ok(true)
}

#[cfg(not(feature = "pgp"))]
pub fn generate_test_key(_user_id: &str) -> Result<()> {
    Ok(())
}

#[cfg(not(feature = "pgp"))]
pub fn export_cert(_cert: &()) -> Result<Vec<u8>> {
    Ok(Vec::new())
}

#[cfg(not(feature = "pgp"))]
pub fn import_cert(_armored: &[u8]) -> Result<()> {
    Ok(())
}

#[cfg(all(test, feature = "pgp"))]
mod tests {
    use super::*;

    #[test]
    fn test_sign_verify_roundtrip() {
        let cert = generate_test_key("test@vaultmesh.dev").unwrap();
        let data = b"VaultMesh Covenant Test";

        let sig = sign_detached(&cert, None, data).unwrap();
        assert!(!sig.is_empty());
        assert!(sig.starts_with(b"-----BEGIN PGP SIGNATURE-----"));

        let valid = verify_detached(&cert, &sig, data).unwrap();
        assert!(valid);
    }

    #[test]
    fn test_export_import_cert() {
        let cert = generate_test_key("test@vaultmesh.dev").unwrap();
        let armored = export_cert(&cert).unwrap();
        assert!(armored.starts_with(b"-----BEGIN PGP PUBLIC KEY BLOCK-----"));

        let imported = import_cert(&armored).unwrap();
        assert_eq!(cert.fingerprint(), imported.fingerprint());
    }
}
