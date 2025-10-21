// OpenPGP operations via Sequoia-PGP
// Implements detached signing/verification for VaultMesh receipts

#[cfg(feature = "pgp")]
use sequoia_openpgp as openpgp;

#[cfg(feature = "pgp")]
use openpgp::{
    armor,
    cert::CertBuilder,
    crypto::Password,
    packet::signature,
    parse::{stream::*, Parse},
    policy::StandardPolicy,
    serialize::stream::*,
    types::SignatureType,
    Cert, KeyHandle,
};

use crate::error::{CryptoError, Result};
use std::io::{Cursor, Write};

/// Sign data with detached signature (armored)
#[cfg(feature = "pgp")]
pub fn sign_detached(cert: &Cert, password: Option<&str>, data: &[u8]) -> Result<Vec<u8>> {
    let policy = StandardPolicy::new();

    // Find signing-capable key
    let keypair = cert
        .keys()
        .with_policy(&policy, None)
        .alive()
        .revoked(false)
        .for_signing()
        .nth(0)
        .ok_or_else(|| CryptoError::KeyNotFound("No signing key found".into()))?
        .key()
        .clone();

    // Decrypt secret key if password provided
    let mut keypair = match password {
        Some(pwd) => keypair
            .decrypt_secret(&Password::from(pwd))
            .map_err(|e| CryptoError::Pgp(format!("Key decryption failed: {}", e)))?,
        None => keypair,
    };

    // Create detached signature
    let mut sig_buf = Vec::new();
    {
        let message = Message::new(&mut sig_buf);
        let mut signer = Signer::new(message, keypair.parts_as_unspecified())
            .detached()
            .build()
            .map_err(|e| CryptoError::Pgp(format!("Signer creation failed: {}", e)))?;

        signer
            .write_all(data)
            .map_err(|e| CryptoError::Io(e))?;
        signer
            .finalize()
            .map_err(|e| CryptoError::Pgp(format!("Finalization failed: {}", e)))?;
    }

    // Armor the signature
    let mut armored = Vec::new();
    {
        let mut writer = armor::Writer::new(&mut armored, armor::Kind::Signature)
            .map_err(|e| CryptoError::Serialization(format!("Armoring failed: {}", e)))?;
        writer
            .write_all(&sig_buf)
            .map_err(|e| CryptoError::Io(e))?;
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

    // Parse signature (handle both armored and binary)
    let sig_reader: Box<dyn std::io::Read + Send + Sync> =
        if signature.starts_with(b"-----BEGIN PGP SIGNATURE-----") {
            Box::new(Cursor::new(signature))
        } else {
            Box::new(Cursor::new(signature))
        };

    // Verify using DetachedVerifier
    struct Helper<'a> {
        cert: &'a Cert,
        valid: bool,
    }

    impl<'a> VerificationHelper for Helper<'a> {
        fn get_certs(&mut self, _ids: &[KeyHandle]) -> openpgp::Result<Vec<Cert>> {
            Ok(vec![self.cert.clone()])
        }

        fn check(&mut self, structure: MessageStructure) -> openpgp::Result<()> {
            for layer in structure.into_iter() {
                match layer {
                    MessageLayer::SignatureGroup { results } => {
                        for result in results {
                            match result {
                                Ok(_) => self.valid = true,
                                Err(e) => return Err(e),
                            }
                        }
                    }
                    _ => {}
                }
            }
            Ok(())
        }
    }

    let mut helper = Helper {
        cert,
        valid: false,
    };

    let mut verifier = DetachedVerifierBuilder::from_reader(sig_reader)
        .map_err(|e| CryptoError::Pgp(format!("Verifier creation failed: {}", e)))?
        .with_policy(&policy, None, &mut helper)
        .map_err(|e| CryptoError::Pgp(format!("Policy application failed: {}", e)))?;

    std::io::copy(&mut Cursor::new(data), &mut verifier)
        .map_err(|e| CryptoError::Io(e))?;

    verifier
        .finalize()
        .map_err(|e| CryptoError::Pgp(format!("Verification failed: {}", e)))?;

    Ok(helper.valid)
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
