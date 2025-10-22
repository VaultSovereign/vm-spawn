use anyhow::Result;
use blake3::Hash;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceiptPart {
    pub label: String,
    pub hash_hex: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Receipt {
    pub parts: Vec<ReceiptPart>,
    pub merkle_root_hex: String,
}

#[derive(Default)]
pub struct ReceiptBuilder {
    leaves: Vec<Hash>,
    parts: Vec<ReceiptPart>,
}

impl ReceiptBuilder {
    pub fn push_labeled(&mut self, label: impl Into<String>, bytes: &[u8]) {
        let h = blake3::hash(bytes);
        self.leaves.push(h);
        self.parts.push(ReceiptPart {
            label: label.into(),
            hash_hex: hex::encode(h.as_bytes()),
        });
    }

    pub fn finalize(self) -> Result<Receipt> {
        let root = merkleize(&self.leaves);
        Ok(Receipt {
            parts: self.parts,
            merkle_root_hex: hex::encode(root.as_bytes()),
        })
    }
}

/// Simple pairwise Merkle (duplicate last if odd)
pub fn merkleize(leaves: &[Hash]) -> Hash {
    if leaves.is_empty() {
        return blake3::hash(&[]);
    }
    let mut level: Vec<Hash> = leaves.to_vec();
    while level.len() > 1 {
        let mut next = Vec::with_capacity((level.len() + 1) / 2);
        let mut i = 0;
        while i < level.len() {
            let a = level[i];
            let b = if i + 1 < level.len() { level[i + 1] } else { level[i] };
            let mut buf = Vec::with_capacity(64);
            buf.extend_from_slice(a.as_bytes());
            buf.extend_from_slice(b.as_bytes());
            next.push(blake3::hash(&buf));
            i += 2;
        }
        level = next;
    }
    level[0]
}
