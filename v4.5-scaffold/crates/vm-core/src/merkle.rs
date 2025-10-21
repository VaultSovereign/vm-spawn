// Merkle Tree implementation for tamper-evident audit log
// Covenant II (Albedo): Reproducibility via deterministic hashing

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MerkleProof {
    pub leaf_hash: [u8; 32],
    pub path: Vec<[u8; 32]>,
}

/// Compute leaf hash (prefix 0x00 to distinguish from internal nodes)
pub fn leaf_hash(data: &[u8]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update([0x00]);
    h.update(data);
    h.finalize().into()
}

/// Compute internal node hash (prefix 0x01)
pub fn node_hash(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update([0x01]);
    h.update(left);
    h.update(right);
    h.finalize().into()
}

/// Compute Merkle root from leaf hashes
pub fn compute_root(mut leaves: Vec<[u8; 32]>) -> Option<[u8; 32]> {
    if leaves.is_empty() {
        return None;
    }
    while leaves.len() > 1 {
        let mut next = Vec::with_capacity((leaves.len() + 1) / 2);
        for chunk in leaves.chunks(2) {
            next.push(match chunk {
                [a, b] => node_hash(a, b),
                [a] => node_hash(a, a), // Duplicate odd leaf
                _ => unreachable!(),
            });
        }
        leaves = next;
    }
    Some(leaves[0])
}

/// Generate Merkle proof for a leaf at given index
pub fn generate_proof(leaves: &[[u8; 32]], leaf_index: usize) -> Option<MerkleProof> {
    if leaf_index >= leaves.len() {
        return None;
    }

    let mut path = Vec::new();
    let mut current_leaves = leaves.to_vec();
    let mut current_index = leaf_index;

    while current_leaves.len() > 1 {
        // Find sibling index
        let sibling_index = if current_index % 2 == 0 {
            current_index + 1
        } else {
            current_index - 1
        };

        // Add sibling to proof path (or duplicate if no sibling)
        let sibling = if sibling_index < current_leaves.len() {
            current_leaves[sibling_index]
        } else {
            current_leaves[current_index]
        };
        path.push(sibling);

        // Move to next level
        let mut next_level = Vec::with_capacity((current_leaves.len() + 1) / 2);
        for chunk in current_leaves.chunks(2) {
            next_level.push(match chunk {
                [a, b] => node_hash(a, b),
                [a] => node_hash(a, a),
                _ => unreachable!(),
            });
        }
        current_leaves = next_level;
        current_index /= 2;
    }

    Some(MerkleProof {
        leaf_hash: leaves[leaf_index],
        path,
    })
}

/// Verify Merkle proof against root
pub fn verify_proof(proof: &MerkleProof, root: &[u8; 32]) -> bool {
    let mut current = proof.leaf_hash;
    for sibling in &proof.path {
        current = node_hash(&current, sibling);
    }
    &current == root
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_merkle_single_leaf() {
        let leaf = leaf_hash(b"test");
        let root = compute_root(vec![leaf]).unwrap();
        assert_eq!(root, leaf);
    }

    #[test]
    fn test_merkle_two_leaves() {
        let l1 = leaf_hash(b"a");
        let l2 = leaf_hash(b"b");
        let root = compute_root(vec![l1, l2]).unwrap();
        assert_eq!(root, node_hash(&l1, &l2));
    }

    #[test]
    fn test_merkle_empty() {
        assert!(compute_root(vec![]).is_none());
    }

    #[test]
    fn test_merkle_proof_generation_and_verification() {
        let leaves: Vec<[u8; 32]> = vec![
            leaf_hash(b"receipt1"),
            leaf_hash(b"receipt2"),
            leaf_hash(b"receipt3"),
            leaf_hash(b"receipt4"),
        ];
        let root = compute_root(leaves.clone()).unwrap();

        // Verify all leaves
        for (i, _) in leaves.iter().enumerate() {
            let proof = generate_proof(&leaves, i).unwrap();
            assert!(verify_proof(&proof, &root), "Proof {} failed", i);
        }
    }

    #[test]
    fn test_merkle_tamper_detection() {
        let leaves: Vec<[u8; 32]> = vec![leaf_hash(b"a"), leaf_hash(b"b")];
        let root = compute_root(leaves.clone()).unwrap();

        let proof = generate_proof(&leaves, 0).unwrap();
        assert!(verify_proof(&proof, &root));

        // Tamper with proof
        let mut tampered_proof = proof.clone();
        tampered_proof.leaf_hash[0] ^= 0xFF;
        assert!(!verify_proof(&tampered_proof, &root));
    }
}

#[cfg(test)]
mod proptests {
    use super::*;
    use proptest::prelude::*;

    // Generate arbitrary byte arrays for leaves
    fn arb_leaves() -> impl Strategy<Value = Vec<Vec<u8>>> {
        prop::collection::vec(prop::collection::vec(any::<u8>(), 1..100), 1..20)
    }

    proptest! {
        #[test]
        fn proptest_merkle_root_deterministic(data in arb_leaves()) {
            let leaves: Vec<[u8; 32]> = data.iter().map(|d| leaf_hash(d)).collect();
            let r1 = compute_root(leaves.clone());
            let r2 = compute_root(leaves.clone());
            prop_assert_eq!(r1, r2, "Merkle root not deterministic");
        }

        #[test]
        fn proptest_merkle_proof_always_valid(data in arb_leaves()) {
            let leaves: Vec<[u8; 32]> = data.iter().map(|d| leaf_hash(d)).collect();
            if let Some(root) = compute_root(leaves.clone()) {
                for i in 0..leaves.len() {
                    if let Some(proof) = generate_proof(&leaves, i) {
                        prop_assert!(
                            verify_proof(&proof, &root),
                            "Valid proof {} should verify",
                            i
                        );
                    }
                }
            }
        }

        #[test]
        fn proptest_tampered_proof_fails(data in arb_leaves(), flip_byte in 0usize..32) {
            let leaves: Vec<[u8; 32]> = data.iter().map(|d| leaf_hash(d)).collect();
            if leaves.len() < 2 {
                return Ok(());
            }
            if let Some(root) = compute_root(leaves.clone()) {
                if let Some(mut proof) = generate_proof(&leaves, 0) {
                    // Tamper with leaf hash
                    proof.leaf_hash[flip_byte] ^= 0xFF;
                    prop_assert!(
                        !verify_proof(&proof, &root),
                        "Tampered proof should fail verification"
                    );
                }
            }
        }
    }
}
