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
async fn created_too_old_yields_clock_skew_error() {
    let (signing, verifying) = gen_keypair();
    let keyid = "ed25519-skew".to_string();
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
            max_skew_secs: 60,
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
    builder.push_labeled("job_id", b"skew");
    builder.push_labeled("final_value", b"1");
    let receipt = builder.finalize().expect("finalize receipt");
    let body_bytes = serde_json::to_vec(&receipt).expect("serialize receipt");

    let mut http_req = Request::post(format!("http://{}/callback", local_addr))
        .header("content-type", "application/json")
        .body(body_bytes.clone())
        .expect("build request");

    let created = OffsetDateTime::now_utc().unix_timestamp() - 600;
    let nonce = "nonce-skew";
    sign_request_with(&mut http_req, &body_bytes, &kp, created, Some(nonce))
        .expect("sign request");

    let mut reqwest_headers = ReqwestHeaderMap::new();
    for (name, value) in http_req.headers().iter() {
        let header_name = ReqwestHeaderName::from_bytes(name.as_str().as_bytes()).unwrap();
        reqwest_headers.append(header_name, value.clone());
    }

    let client = reqwest::Client::new();
    let response = client
        .post(format!("http://{}/callback", local_addr))
        .headers(reqwest_headers)
        .body(body_bytes)
        .send()
        .await
        .expect("send request");

    assert_eq!(response.status(), reqwest::StatusCode::BAD_REQUEST);

    let _ = tx.send(());
    server_handle.await.expect("server task");
}
