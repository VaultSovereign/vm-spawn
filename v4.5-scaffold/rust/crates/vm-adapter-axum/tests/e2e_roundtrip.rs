use std::{
    collections::HashMap,
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
};

use axum::http::Request;
use ed25519_dalek::SigningKey;
use rand_core::OsRng;
use reqwest::header::{HeaderMap as ReqwestHeaderMap, HeaderName as ReqwestHeaderName};
use time::OffsetDateTime;
use tokio::sync::oneshot;
use vm_adapter_axum::{run_with_addr, AppState};
use vm_httpsig::{sign_request_with, KeyPair, MemoryNonceStore, NonceStore, VerifyOptions};
use vm_receipt::ReceiptBuilder;

#[tokio::test]
async fn signed_callback_roundtrip_succeeds() {
    // Generate an in-memory Ed25519 keypair for the test.
    let signing = SigningKey::generate(&mut OsRng);
    let verifying = signing.verifying_key();
    let keyid = "ed25519-test".to_string();
    let kp = KeyPair {
        signing,
        verifying,
        keyid: keyid.clone(),
    };

    // Prepare shared state for the server.
    let mut km = HashMap::new();
    km.insert(keyid.clone(), kp.verifying.clone());
    let nonce_store: Arc<dyn NonceStore> = Arc::new(MemoryNonceStore::new(300));
    let state = AppState {
        key_map: Arc::new(km),
        nonces: Some(nonce_store),
        opts: VerifyOptions {
            max_skew_secs: 300,
            require_nonce: true,
        },
    };

    // Bind to an ephemeral port to discover an available address.
    let bind_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    let listener = std::net::TcpListener::bind(bind_addr).expect("bind temp listener");
    let local_addr = listener.local_addr().unwrap();
    drop(listener);

    // Server shutdown coordination.
    let (tx, rx) = oneshot::channel::<()>();
    let server_state = state.clone();
    let server_handle = tokio::spawn(async move {
        run_with_addr(server_state, local_addr, async {
            let _ = rx.await;
        })
        .await
        .unwrap();
    });

    // Build a minimal receipt body.
    let mut builder = ReceiptBuilder::default();
    builder.push_labeled("job_id", b"e2e");
    builder.push_labeled("final_value", b"42");
    let receipt = builder.finalize().expect("finalize receipt");
    let body_bytes = serde_json::to_vec(&receipt).expect("serialize receipt");

    // Construct an HTTP request and sign it using the library helper.
    let mut http_req = Request::post(format!("http://{}/callback", local_addr))
        .header("content-type", "application/json")
        .body(body_bytes.clone())
        .expect("build request");

    let created = OffsetDateTime::now_utc().unix_timestamp();
    let nonce = "nonce-roundtrip";
    sign_request_with(&mut http_req, &body_bytes, &kp, created, Some(nonce))
        .expect("sign request");

    // Convert the signed headers into a reqwest HeaderMap.
    let mut reqwest_headers = ReqwestHeaderMap::new();
    for (name, value) in http_req.headers().iter() {
        let header_name = ReqwestHeaderName::from_bytes(name.as_str().as_bytes()).unwrap();
        reqwest_headers.append(header_name, value.clone());
    }

    // Dispatch the request against the running server.
    let client = reqwest::Client::new();
    let response = client
        .post(format!("http://{}/callback", local_addr))
        .headers(reqwest_headers)
        .body(body_bytes)
        .send()
        .await
        .expect("send request");

    assert!(response.status().is_success(), "status: {}", response.status());

    // Signal shutdown and wait for the server task to finish.
    let _ = tx.send(());
    server_handle.await.expect("server task");
}
