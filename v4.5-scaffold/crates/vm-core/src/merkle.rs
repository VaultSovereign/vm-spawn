//! Merkle tree for tamper-evident receipt logs

use sha2::{Sha256, Digest};
use serde::{Deserialize, Serialize};

/// Merkle proof (path from leaf to root)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MerkleProof {
    pub leaf_index: usize,
    pub path: Vec<[u8; 32]>,
}

/// Merkle tree (binary tree of hashes)
#[derive(Debug, Clone)]
pub struct MerkleTree {
    pub leaves: Vec<[u8; 32]>,
    pub root: [u8; 32],
}

impl MerkleTree {
    /// Build Merkle tree from leaf hashes
    pub fn new(leaves: Vec<[u8; 32]>) -> Self {
        if leaves.is_empty() {
            return Self {
                leaves: vec![],
                root: [0u8; 32],
            };
        }

        let root = Self::compute_root(&leaves);
        Self { leaves, root }
    }

    /// Compute Merkle root from leaves
    fn compute_root(leaves: &[[u8; 32]]) -> [u8; 32] {
        if leaves.is_empty() {
            return [0u8; 32];
        }

        if leaves.len() == 1 {
            return leaves[0];
        }

        // Build tree bottom-up
        let mut layer = leaves.to_vec();
        while layer.len() > 1 {
            let mut next_layer = Vec::new();
            for chunk in layer.chunks(2) {
                let hash = if chunk.len() == 2 {
                    hash_pair(&chunk[0], &chunk[1])
                } else {
                    // Odd node: hash with itself
                    hash_pair(&chunk[0], &chunk[0])
                };
                next_layer.push(hash);
            }
            layer = next_layer;
        }

        layer[0]
    }

    /// Generate Merkle proof for leaf at index
    pub fn proof(&self, index: usize) -> Option<MerkleProof> {
        if index >= self.leaves.len() {
            return None;
        }

        let mut path = Vec::new();
        let mut layer = self.leaves.clone();
        let mut idx = index;

        while layer.len() > 1 {
            let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };

            let sibling = if sibling_idx < layer.len() {
                layer[sibling_idx]
            } else {
                layer[idx] // Duplicate self if odd
            };

            path.push(sibling);

            // Move to next layer
            let mut next_layer = Vec::new();
            for chunk in layer.chunks(2) {
                let hash = if chunk.len() == 2 {
                    hash_pair(&chunk[0], &chunk[1])
                } else {
                    hash_pair(&chunk[0], &chunk[0])
                };
                next_layer.push(hash);
            }
            layer = next_layer;
            idx /= 2;
        }

        Some(MerkleProof {
            leaf_index: index,
            path,
        })
    }

    /// Verify Merkle proof
    pub fn verify(leaf: &[u8; 32], proof: &MerkleProof, root: &[u8; 32]) -> bool {
        let mut current = *leaf;
        let mut idx = proof.leaf_index;

        for sibling in &proof.path {
            current = if idx % 2 == 0 {
                hash_pair(&current, sibling)
            } else {
                hash_pair(sibling, &current)
            };
            idx /= 2;
        }

        current == *root
    }
}

/// Hash two nodes (left || right)
fn hash_pair(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(left);
    hasher.update(right);
    hasher.finalize().into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn leaf(n: u8) -> [u8; 32] {
        let mut hasher = Sha256::new();
        hasher.update(&[n]);
        hasher.finalize().into()
    }

    #[test]
    fn test_merkle_single_leaf() {
        let leaves = vec![leaf(0)];
        let tree = MerkleTree::new(leaves.clone());
        assert_eq!(tree.root, leaves[0]);
    }

    #[test]
    fn test_merkle_two_leaves() {
        let leaves = vec![leaf(0), leaf(1)];
        let tree = MerkleTree::new(leaves.clone());

        let expected_root = hash_pair(&leaves[0], &leaves[1]);
        assert_eq!(tree.root, expected_root);
    }

    #[test]
    fn test_merkle_proof_verify() {
        let leaves = vec![leaf(0), leaf(1), leaf(2), leaf(3)];
        let tree = MerkleTree::new(leaves.clone());

        // Verify proof for each leaf
        for (i, leaf_hash) in leaves.iter().enumerate() {
            let proof = tree.proof(i).unwrap();
            assert!(MerkleTree::verify(leaf_hash, &proof, &tree.root));
        }
    }

    #[test]
    fn test_merkle_tamper_detection() {
        let leaves = vec![leaf(0), leaf(1), leaf(2)];
        let tree = MerkleTree::new(leaves.clone());

        let proof = tree.proof(1).unwrap();

        // Valid proof
        assert!(MerkleTree::verify(&leaves[1], &proof, &tree.root));

        // Tampered leaf
        let tampered = leaf(99);
        assert!(!MerkleTree::verify(&tampered, &proof, &tree.root));

        // Wrong root
        let wrong_root = [0xff; 32];
        assert!(!MerkleTree::verify(&leaves[1], &proof, &wrong_root));
    }

    #[test]
    fn test_merkle_empty() {
        let tree = MerkleTree::new(vec![]);
        assert_eq!(tree.root, [0u8; 32]);
        assert!(tree.proof(0).is_none());
    }
}

#[cfg(test)]
mod proptests {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn merkle_root_deterministic(n in 1usize..100) {
            let leaves: Vec<[u8; 32]> = (0..n).map(|i| {
                let mut h = Sha256::new();
                h.update(&[i as u8]);
                h.finalize().into()
            }).collect();

            let tree1 = MerkleTree::new(leaves.clone());
            let tree2 = MerkleTree::new(leaves.clone());
            prop_assert_eq!(tree1.root, tree2.root);
        }

        #[test]
        fn merkle_proof_always_valid(n in 1usize..100, idx in 0usize..99) {
            let n = n.max(1);
            let idx = idx % n;

            let leaves: Vec<[u8; 32]> = (0..n).map(|i| {
                let mut h = Sha256::new();
                h.update(&[i as u8]);
                h.finalize().into()
            }).collect();

            let tree = MerkleTree::new(leaves.clone());
            let proof = tree.proof(idx).unwrap();
            prop_assert!(MerkleTree::verify(&leaves[idx], &proof, &tree.root));
        }
    }
}
