use anyhow::Result;
use std::{collections::HashMap, net::SocketAddr, sync::Arc};
use vm_adapter_axum::{run_with_addr, AppState};
use vm_httpsig::{KeyPair, MemoryNonceStore, NonceStore, VerifyOptions};

#[tokio::main]
async fn main() -> Result<()> {
    let key_path =
        std::env::var("VM_DEMO_KEY").unwrap_or_else(|_| "examples/dev-ed25519.pem".into());
    let kp = KeyPair::from_pem_file(&key_path, "ed25519-1")?;

    let mut km = HashMap::new();
    km.insert(kp.keyid.clone(), kp.verifying.clone());
    let nonce_store: Arc<dyn NonceStore> = Arc::new(MemoryNonceStore::new(300));
    let state = AppState {
        key_map: Arc::new(km),
        nonces: Some(nonce_store),
        opts: VerifyOptions {
            max_skew_secs: 120,
            require_nonce: true,
        },
    };

    let port: u16 = std::env::var("PORT").ok().and_then(|v| v.parse().ok()).unwrap_or(3000);
    let addr: SocketAddr = format!("127.0.0.1:{port}").parse().unwrap();

    run_with_addr(state, addr, std::future::pending()).await
}
