use thiserror::Error;

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("OpenPGP error: {0}")]
    Pgp(String),

    #[error("RFC3161 timestamp error: {0}")]
    Timestamp(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Key not found: {0}")]
    KeyNotFound(String),

    #[error("Invalid signature")]
    InvalidSignature,

    #[error("Network error: {0}")]
    Network(String),
}

pub type Result<T> = std::result::Result<T, CryptoError>;
