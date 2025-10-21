//! VaultMesh Core — Domain types and canonical serialization
//!
//! This crate provides:
//! - Receipt types (deployment records, cryptographic proofs)
//! - Canonical JSON serialization (JCS, RFC 8785)
//! - Content-addressed IDs (SHA-256 of canonical JSON)
//! - Merkle tree utilities

pub mod receipt;
pub mod canonical;
pub mod merkle;

pub use receipt::{Receipt, Artifact, ReceiptId};
pub use canonical::{to_canonical, from_canonical, content_id};
pub use merkle::{MerkleTree, MerkleProof};
