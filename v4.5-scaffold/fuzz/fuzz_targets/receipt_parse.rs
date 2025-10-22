#![no_main]
use libfuzzer_sys::fuzz_target;
fuzz_target!(|data: &[u8]| {
  if let Ok(v)=serde_json::from_slice::<serde_json::Value>(data){
    let _ = vm_core::canonical::to_jcs_bytes(&v);
  }
});
