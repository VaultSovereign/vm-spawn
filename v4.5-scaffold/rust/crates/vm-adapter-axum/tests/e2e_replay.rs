use std::{
    collections::HashMap,
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::Arc,
};

use axum::http::Request;
use ed25519_dalek::{SigningKey, VerifyingKey};
use rand_core::OsRng;
use reqwest::header::{HeaderMap as ReqwestHeaderMap, HeaderName as ReqwestHeaderName};
use time::OffsetDateTime;
use tokio::sync::oneshot;
use vm_adapter_axum::{run_with_addr, AppState};
use vm_httpsig::{sign_request_with, KeyPair, MemoryNonceStore, NonceStore, VerifyOptions};
use vm_receipt::ReceiptBuilder;

fn gen_keypair() -> (SigningKey, VerifyingKey) {
    let signing = SigningKey::generate(&mut OsRng);
    let verifying = signing.verifying_key();
    (signing, verifying)
}

#[tokio::test]
async fn replayed_nonce_returns_conflict() {
    let (signing, verifying) = gen_keypair();
    let keyid = "ed25519-1".to_string();
    let kp = KeyPair {
        signing,
        verifying: verifying.clone(),
        keyid: keyid.clone(),
    };

    let mut km = HashMap::new();
    km.insert(keyid.clone(), verifying);
    let nonce_store: Arc<dyn NonceStore> = Arc::new(MemoryNonceStore::new(300));
    let state = AppState {
        key_map: Arc::new(km),
        nonces: Some(nonce_store),
        opts: VerifyOptions {
            max_skew_secs: 300,
            require_nonce: true,
        },
    };

    let bind_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    let listener = std::net::TcpListener::bind(bind_addr).expect("bind temp listener");
    let local_addr = listener.local_addr().unwrap();
    drop(listener);

    let (tx, rx) = oneshot::channel::<()>();
    let server_state = state.clone();
    let server_handle = tokio::spawn(async move {
        run_with_addr(server_state, local_addr, async {
            let _ = rx.await;
        })
        .await
        .unwrap();
    });

    let mut builder = ReceiptBuilder::default();
    builder.push_labeled("job_id", b"rep");
    builder.push_labeled("final_value", b"1");
    let receipt = builder.finalize().expect("finalize receipt");
    let body_bytes = serde_json::to_vec(&receipt).expect("serialize receipt");

    let nonce = "fixed-nonce";
    let created = OffsetDateTime::now_utc().unix_timestamp();

    let mut send_signed = |body: &[u8]| async {
        let mut req = Request::post(format!("http://{}/callback", local_addr))
            .header("content-type", "application/json")
            .body(body.to_vec())
            .expect("build request");
        sign_request_with(&mut req, body, &kp, created, Some(nonce)).expect("sign request");

        let mut header_map = ReqwestHeaderMap::new();
        for (name, value) in req.headers().iter() {
            let header_name = ReqwestHeaderName::from_bytes(name.as_str().as_bytes()).unwrap();
            header_map.append(header_name, value.clone());
        }

        reqwest::Client::new()
            .post(format!("http://{}/callback", local_addr))
            .headers(header_map)
            .body(body.to_vec())
            .send()
            .await
            .expect("send request")
    };

    let response1 = send_signed(&body_bytes).await;
    assert!(response1.status().is_success());

    let response2 = send_signed(&body_bytes).await;
    assert_eq!(response2.status(), reqwest::StatusCode::CONFLICT);

    let _ = tx.send(());
    server_handle.await.expect("server task");
}
