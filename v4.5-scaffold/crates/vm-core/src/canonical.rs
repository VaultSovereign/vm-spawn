use anyhow::Result; use serde::Serialize;
pub fn to_jcs_bytes<T: Serialize>(v:&T)->Result<Vec<u8>>{ Ok(serde_jcs::to_vec(v)?) }
