use anyhow::{anyhow, Context, Result};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use ed25519_dalek::{pkcs8::DecodePrivateKey, Signature, Signer, SigningKey, VerifyingKey};
use http::{HeaderMap, HeaderValue, Method, Request};
use parking_lot::Mutex;
use sha2::{Digest, Sha256};
use time::OffsetDateTime;

/// Verification tuning knobs.
#[derive(Clone, Copy)]
pub struct VerifyOptions {
    /// Allowed clock skew for `created` (seconds). If zero, skip the check.
    pub max_skew_secs: i64,
    /// If true, a missing nonce is an error. If false, nonce is optional.
    pub require_nonce: bool,
}

impl Default for VerifyOptions {
    fn default() -> Self {
        Self {
            max_skew_secs: 0,
            require_nonce: false,
        }
    }
}

/// Interface for replay protection.
pub trait NonceStore: Send + Sync + 'static {
    /// Returns true if this nonce has been seen before (replay detected).
    fn seen(&self, nonce: &str, created: i64) -> Result<bool>;
}

/// Simple in-memory NonceStore with time-based GC.
pub struct MemoryNonceStore {
    ttl_secs: i64,
    map: Mutex<std::collections::HashMap<String, i64>>,
}

impl MemoryNonceStore {
    pub fn new(ttl_secs: i64) -> Self {
        Self {
            ttl_secs,
            map: Mutex::new(std::collections::HashMap::new()),
        }
    }

    fn now() -> i64 {
        OffsetDateTime::now_utc().unix_timestamp()
    }
}

impl NonceStore for MemoryNonceStore {
    fn seen(&self, nonce: &str, created: i64) -> Result<bool> {
        let mut map = self.map.lock();
        let now = Self::now();
        map.retain(|_, ts| now - *ts <= self.ttl_secs);
        Ok(map.insert(nonce.to_string(), created).is_some())
    }
}

/// Create a Content-Digest header per RFC 9231 (sha-256)
pub fn content_digest_sha256(body: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(body);
    let digest = hasher.finalize();
    format!("sha-256=:{}:", B64.encode(digest))
}

/// Build the `Signature-Input` (supports optional nonce)
fn signature_input(created: i64, keyid: &str, nonce: Option<&str>) -> String {
    match nonce {
        Some(nonce) => format!(
            "sig1=(\"@method\" \"@path\" \"@authority\" \"content-digest\");created={};nonce=\"{}\";keyid=\"{}\"",
            created, nonce, keyid
        ),
        None => format!(
            "sig1=(\"@method\" \"@path\" \"@authority\" \"content-digest\");created={};keyid=\"{}\"",
            created, keyid
        ),
    }
}

/// Build the signature base per RFC 9421 style (simplified)
fn signature_base(
    method: &Method,
    path: &str,
    authority: &str,
    content_digest: &str,
    sig_input_value: &str,
) -> String {
    let mut lines = Vec::new();
    lines.push(format!("\"@method\": {}", method.as_str().to_lowercase()));
    lines.push(format!("\"@path\": {}", path));
    lines.push(format!("\"@authority\": {}", authority));
    lines.push(format!("\"content-digest\": {}", content_digest));
    lines.push(format!("\"@signature-params\": {}", sig_input_value));
    lines.join("\n")
}

pub struct KeyPair {
    pub signing: SigningKey,
    pub verifying: VerifyingKey,
    pub keyid: String,
}

impl KeyPair {
    pub fn from_pem_file(path: &str, keyid: impl Into<String>) -> Result<Self> {
        let pem =
            std::fs::read_to_string(path).with_context(|| format!("reading PEM key from {}", path))?;
        let signing = SigningKey::from_pkcs8_pem(&pem)?;
        let verifying = signing.verifying_key();
        Ok(Self {
            signing,
            verifying,
            keyid: keyid.into(),
        })
    }
}

/// Sign an outbound request (mutates headers). Returns created timestamp used.
pub fn sign_request<B: AsRef<[u8]>>(
    req: &mut Request<B>,
    body_bytes: &[u8],
    kp: &KeyPair,
) -> Result<i64> {
    let created = OffsetDateTime::now_utc().unix_timestamp();
    sign_request_with(req, body_bytes, kp, created, None)
}

/// Sign an outbound request with explicit created time and optional nonce.
pub fn sign_request_with<B: AsRef<[u8]>>(
    req: &mut Request<B>,
    body_bytes: &[u8],
    kp: &KeyPair,
    created: i64,
    nonce: Option<&str>,
) -> Result<i64> {
    let cd = content_digest_sha256(body_bytes);
    req.headers_mut()
        .insert("content-digest", HeaderValue::from_str(&cd)?);

    let sig_input = signature_input(created, &kp.keyid, nonce);
    req.headers_mut()
        .insert("signature-input", HeaderValue::from_str(&sig_input)?);

    let (method, path, auth) = extract_req_components(req)?;
    let base = signature_base(&method, &path, &auth, &cd, &sig_input);
    let sig = kp.signing.sign(base.as_bytes());
    let sig_val = format!("sig1=:{}:", B64.encode(sig.to_bytes()));
    req.headers_mut()
        .insert("signature", HeaderValue::from_str(&sig_val)?);

    Ok(created)
}

/// Verification error reasons.
#[derive(Debug)]
pub enum VerifyError {
    Missing(&'static str),
    BadFormat(&'static str),
    Signature,
    Skew,
    Replay,
    Other(String),
}

/// Verify inbound request signature using provided key resolver (by keyid).
pub fn verify_request<B>(
    req: &Request<B>,
    key_resolver: impl Fn(&str) -> Option<VerifyingKey>,
) -> Result<()> {
    verify_request_with(req, key_resolver, None, VerifyOptions::default())
        .map_err(|e| anyhow!("{e:?}"))
}

/// Verify inbound request signature with options and optional nonce store.
pub fn verify_request_with<B>(
    req: &Request<B>,
    key_resolver: impl Fn(&str) -> Option<VerifyingKey>,
    nonce_store: Option<&dyn NonceStore>,
    opts: VerifyOptions,
) -> std::result::Result<(), VerifyError> {
    let headers = req.headers();

    let sig_input =
        get_str(headers, "signature-input").map_err(|_| VerifyError::Missing("signature-input"))?;
    let sig_field = get_str(headers, "signature").map_err(|_| VerifyError::Missing("signature"))?;
    let content_digest =
        get_str(headers, "content-digest").map_err(|_| VerifyError::Missing("content-digest"))?;

    let keyid = parse_param(sig_input, "keyid").ok_or(VerifyError::BadFormat("keyid"))?;
    let created = parse_param(sig_input, "created")
        .and_then(|s| s.parse::<i64>().ok())
        .ok_or(VerifyError::BadFormat("created"))?;
    let nonce = parse_param(sig_input, "nonce");

    if opts.require_nonce && nonce.is_none() {
        return Err(VerifyError::Missing("nonce"));
    }

    if opts.max_skew_secs > 0 {
        let now = OffsetDateTime::now_utc().unix_timestamp();
        if (now - created).abs() > opts.max_skew_secs {
            return Err(VerifyError::Skew);
        }
    }

    if let (Some(store), Some(nonce)) = (nonce_store, nonce.as_deref()) {
        if store
            .seen(nonce, created)
            .map_err(|e| VerifyError::Other(e.to_string()))?
        {
            return Err(VerifyError::Replay);
        }
    }

    let vk = key_resolver(&keyid).ok_or_else(|| VerifyError::Other("unknown keyid".into()))?;

    let (method, path, auth) =
        extract_req_components(req).map_err(|_| VerifyError::Other("req components".into()))?;
    let base = signature_base(&method, &path, &auth, content_digest, sig_input);

    let b64 = sig_field
        .split(':')
        .nth(1)
        .ok_or(VerifyError::BadFormat("Signature"))?;
    let sig_bytes = B64
        .decode(b64)
        .map_err(|_| VerifyError::BadFormat("Signature b64"))?;
    let sig = Signature::from_slice(&sig_bytes).map_err(|_| VerifyError::BadFormat("Signature bytes"))?;
    vk.verify_strict(base.as_bytes(), &sig)
        .map_err(|_| VerifyError::Signature)?;
    Ok(())
    Ok(())
}

fn get_str<'a>(headers: &'a HeaderMap, name: &str) -> Result<&'a str> {
    let value = headers
        .get(name)
        .ok_or_else(|| anyhow!("missing header {}", name))?;
    Ok(value.to_str()?)
}

fn parse_param(sig_input: &str, name: &str) -> Option<String> {
    let needle = format!("{name}=\"");
    sig_input.find(&needle).and_then(|idx| {
        let rest = &sig_input[idx + needle.len()..];
        rest.find('"').map(|end| rest[..end].to_string())
    })
}

fn extract_req_components<B>(req: &Request<B>) -> Result<(Method, String, String)> {
    let method = req.method().clone();
    let uri = req.uri();
    let path = uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("/");
    let authority = uri
        .authority()
        .map(|a| a.as_str().to_string())
        .or_else(|| {
            req.headers()
                .get("host")
                .and_then(|h| h.to_str().ok())
                .map(|s| s.to_string())
        })
        .ok_or_else(|| anyhow!("no authority/host"))?;
    Ok((method, path.to_string(), authority))
}
