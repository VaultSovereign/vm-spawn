use anyhow::Result;
#[cfg(feature="pgp")] pub mod pgp {
  use anyhow::Result;
  pub fn sign_detached(data:&[u8])->Result<Vec<u8>>{ let mut v=b"PGP-SIGNATURE-PLACEHOLDER".to_vec(); v.extend_from_slice(&data.len().to_be_bytes()); Ok(v) }
  pub fn verify_detached(_:&[u8], sig:&[u8])->Result<bool>{ Ok(sig.starts_with(b"PGP-SIGNATURE-PLACEHOLDER")) }
}
#[cfg(not(feature="pgp"))] pub mod pgp {
  use anyhow::Result; pub fn sign_detached(_: &[u8])->Result<Vec<u8>>{Ok(Vec::new())} pub fn verify_detached(_: &[u8], _: &[u8])->Result<bool>{Ok(true)}
}
#[cfg(feature="tsa")] pub mod tsa {
  use anyhow::Result; pub fn timestamp_request(_:&[u8])->Result<Vec<u8>>{ Ok(b"TSA-TSR-PLACEHOLDER".to_vec()) }
  pub fn verify_timestamp(_:&[u8], tsr:&[u8])->Result<bool>{ Ok(tsr.starts_with(b"TSA-TSR-PLACEHOLDER")) }
}
#[cfg(not(feature="tsa"))] pub mod tsa {
  use anyhow::Result; pub fn timestamp_request(_:&[u8])->Result<Vec<u8>>{Ok(Vec::new())} pub fn verify_timestamp(_:&[u8], _:&[u8])->Result<bool>{Ok(true)}
}
