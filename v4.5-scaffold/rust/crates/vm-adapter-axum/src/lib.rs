use anyhow::Result;
use axum::{
    body::Body,
    extract::State,
    http::{Request, StatusCode},
    response::IntoResponse,
    routing::post,
    Json, Router,
};
use http_body_util::BodyExt;
use std::{collections::HashMap, future::Future, net::SocketAddr, sync::Arc};
use tracing::{error, info};
use tracing_subscriber::EnvFilter;
use vm_httpsig::{
    verify_request_with, KeyPair, MemoryNonceStore, NonceStore, VerifyError, VerifyOptions,
};
use vm_receipt::Receipt;

#[derive(Clone)]
pub struct AppState {
    pub key_map: Arc<HashMap<String, ed25519_dalek::VerifyingKey>>,
    pub nonces: Option<Arc<dyn NonceStore>>,
    pub opts: VerifyOptions,
}

pub async fn run_demo_server(kp: &KeyPair) -> Result<()> {
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

    let addr: SocketAddr = "127.0.0.1:3000".parse().unwrap();
    run_with_addr(state, addr, std::future::pending()).await
}

/// Build the Axum router that hosts the callback endpoint.
pub fn app_router(state: AppState) -> Router {
    Router::new().route("/callback", post(callback)).with_state(state)
}

/// Run the callback service on the provided address until the shutdown future resolves.
pub async fn run_with_addr(
    state: AppState,
    addr: SocketAddr,
    shutdown: impl Future<Output = ()> + Send + 'static,
) -> Result<()> {
    let _ = tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::new("info,hyper=warn,axum=warn"))
        .try_init();

    info!("listening on http://{}", addr);
    axum::Server::bind(&addr)
        .serve(app_router(state).into_make_service())
        .with_graceful_shutdown(shutdown)
        .await?;
    Ok(())
}

async fn callback(State(state): State<AppState>, req: Request<Body>) -> impl IntoResponse {
    let (parts, body) = req.into_parts();
    match body.collect().await {
        Ok(collected) => {
            let body_bytes = collected.to_bytes();
            let req_rebuilt = Request::from_parts(parts, ());
            let key_resolver = |keyid: &str| state.key_map.get(keyid).cloned();

            match verify_request_with(
                &req_rebuilt,
                key_resolver,
                state.nonces.as_deref(),
                state.opts,
            ) {
                Ok(_) => match serde_json::from_slice::<Receipt>(&body_bytes) {
                    Ok(rcpt) => {
                        info!("verified sig + receipt root={}", rcpt.merkle_root_hex);
                        (StatusCode::OK, Json(serde_json::json!({"ok": true})))
                    }
                    Err(e) => {
                        error!("body parse failed: {e}");
                        (
                            StatusCode::BAD_REQUEST,
                            Json(serde_json::json!({"ok": false, "err":"bad body"})),
                        )
                    }
                },
                Err(err) => {
                    let (status, code) = match err {
                        VerifyError::Replay => (StatusCode::CONFLICT, "replay"),
                        VerifyError::Skew => (StatusCode::BAD_REQUEST, "clock-skew"),
                        VerifyError::Missing(_) | VerifyError::BadFormat(_) => {
                            (StatusCode::BAD_REQUEST, "bad-headers")
                        }
                        VerifyError::Signature => (StatusCode::UNAUTHORIZED, "signature"),
                        VerifyError::Other(_) => (StatusCode::UNAUTHORIZED, "verify"),
                    };
                    error!("verify failed: {err:?}");
                    (status, Json(serde_json::json!({"ok": false, "err": code})))
                }
            }
        }
        Err(e) => {
            error!("body read failed: {e}");
            (
                StatusCode::BAD_REQUEST,
                Json(serde_json::json!({"ok": false, "err":"body"})),
            )
        }
    }
}

// Binary entry point is provided in `src/main.rs` for `cargo run -p vm-adapter-axum`.
