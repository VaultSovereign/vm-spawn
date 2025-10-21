use sha2::{Digest, Sha256}; use serde::{Serialize, Deserialize};
#[derive(Debug, Clone, Serialize, Deserialize)] pub struct MerkleProof{ pub leaf_hash:[u8;32], pub path:Vec<[u8;32]> }
pub fn leaf_hash(data:&[u8])->[u8;32]{ let mut h=Sha256::new(); h.update([0x00]); h.update(data); h.finalize().into() }
pub fn node_hash(l:&[u8;32], r:&[u8;32])->[u8;32]{ let mut h=Sha256::new(); h.update([0x01]); h.update(l); h.update(r); h.finalize().into() }
pub fn compute_root(mut leaves:Vec<[u8;32]>)->Option<[u8;32]>{
  if leaves.is_empty(){return None;}
  while leaves.len()>1{
    let mut next=Vec::with_capacity((leaves.len()+1)/2);
    for c in leaves.chunks(2){ next.push(match c{ [a,b]=>node_hash(a,b), [a]=>node_hash(a,a), _=>unreachable!() }); }
    leaves=next;
  }
  Some(leaves[0])
}
