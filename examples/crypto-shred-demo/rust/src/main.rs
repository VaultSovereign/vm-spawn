use std::collections::{BTreeMap, HashMap};

use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use blake3;
use chrono::Utc;
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{Key, XChaCha20Poly1305, XNonce};
use ed25519_dalek::{Signer, SigningKey, Verifier, VerifyingKey};
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use serde_json::Value;

fn iso_now() -> String {
    Utc::now().to_rfc3339()
}

fn canonical_bytes(map: &BTreeMap<String, String>) -> Vec<u8> {
    serde_json::to_vec(map).unwrap()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LedgerEntry {
    seq: usize,
    #[serde(rename = "type")]
    type_str: String, // "anchor" | "receipt"
    record_id: String,
    blob_hash: Option<String>,
    policy: Option<Vec<String>>,
    key_ref: Option<String>,
    receipt_digest: Option<String>,
    ts: String,
}

#[derive(Default)]
struct Ledger {
    entries: Vec<LedgerEntry>,
}
impl Ledger {
    fn append_anchor(&mut self, record_id: &str, blob_hash: &str, policy: &[String], key_ref: &str) -> LedgerEntry {
        let entry = LedgerEntry {
            seq: self.entries.len(),
            type_str: "anchor".to_string(),
            record_id: record_id.to_string(),
            blob_hash: Some(blob_hash.to_string()),
            policy: Some(policy.to_vec()),
            key_ref: Some(key_ref.to_string()),
            receipt_digest: None,
            ts: iso_now(),
        };
        self.entries.push(entry.clone());
        entry
    }
    fn append_receipt_digest(&mut self, record_id: &str, canonical: &[u8]) -> LedgerEntry {
        let digest = blake3::hash(canonical).to_hex().to_string();
        let entry = LedgerEntry {
            seq: self.entries.len(),
            type_str: "receipt".to_string(),
            record_id: record_id.to_string(),
            blob_hash: None,
            policy: None,
            key_ref: None,
            receipt_digest: Some(digest),
            ts: iso_now(),
        };
        self.entries.push(entry.clone());
        entry
    }
    fn last_anchor(&self, record_id: &str) -> Option<&LedgerEntry> {
        self.entries.iter().rev().find(|e| e.type_str == "anchor" && e.record_id == record_id)
    }
}

struct KeyStore {
    kek: [u8; 32],
    store: HashMap<String, Vec<u8>>, // record_id -> wrap(nonce||ct)
}
impl KeyStore {
    fn new() -> Self {
        let mut kek = [0u8; 32];
        OsRng.fill_bytes(&mut kek);
        Self { kek, store: HashMap::new() }
    }
    fn wrap_and_store(&mut self, record_id: &str, kr: &[u8]) -> String {
        let aead = XChaCha20Poly1305::new(Key::from_slice(&self.kek));
        let mut n = [0u8; 24];
        OsRng.fill_bytes(&mut n);
        let ct = aead.encrypt(
            XNonce::from_slice(&n),
            Payload { msg: kr, aad: record_id.as_bytes() }
        ).expect("wrap");
        let mut blob = n.to_vec();
        blob.extend_from_slice(&ct);
        self.store.insert(record_id.to_string(), blob);
        format!("kms://local/{}#v1", record_id)
    }
    fn unwrap(&self, record_id: &str) -> Option<Vec<u8>> {
        let blob = self.store.get(record_id)?;
        let aead = XChaCha20Poly1305::new(Key::from_slice(&self.kek));
        let (n, ct) = blob.split_at(24);
        let kr = aead.decrypt(
            XNonce::from_slice(n),
            Payload { msg: ct, aad: record_id.as_bytes() }
        ).ok()?;
        Some(kr)
    }
    fn destroy(&mut self, record_id: &str) {
        self.store.remove(record_id);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ErasureReceipt {
    record_id: String,
    anchor_blob_hash: String,
    key_ref: String,
    lawful_basis: String,
    ts: String,
    issuer: String,
    pubkey: String,   // base64 raw
    signature: String // base64 over canonical unsigned map
}
impl ErasureReceipt {
    fn unsigned_map(&self) -> BTreeMap<String, String> {
        // Build without the signature field
        let mut m = BTreeMap::new();
        m.insert("record_id".into(), self.record_id.clone());
        m.insert("anchor_blob_hash".into(), self.anchor_blob_hash.clone());
        m.insert("key_ref".into(), self.key_ref.clone());
        m.insert("lawful_basis".into(), self.lawful_basis.clone());
        m.insert("ts".into(), self.ts.clone());
        m.insert("issuer".into(), self.issuer.clone());
        m.insert("pubkey".into(), self.pubkey.clone());
        m
    }
}

struct Demo {
    ledger: Ledger,
    kms: KeyStore,
    signer: SigningKey,
    blob_store: HashMap<String, Vec<u8>>, // record_id -> sealed (nonce||ct)
}
impl Demo {
    fn new() -> Self {
        Self {
            ledger: Ledger::default(),
            kms: KeyStore::new(),
            signer: SigningKey::generate(&mut OsRng),
            blob_store: HashMap::new(),
        }
    }

    fn aad(record_id: &str, policy: &[String]) -> Vec<u8> {
        // minimal AAD: JSON {"record_id": ..., "policy":[...]}
        let mut obj = serde_json::Map::new();
        obj.insert("record_id".into(), Value::String(record_id.to_string()));
        obj.insert("policy".into(), Value::Array(policy.iter().map(|p| Value::String(p.clone())).collect()));
        serde_json::to_vec(&Value::Object(obj)).unwrap()
    }

    fn seal(kr: &[u8], plaintext: &[u8], aad: &[u8]) -> Vec<u8> {
        let aead = XChaCha20Poly1305::new(Key::from_slice(kr));
        let mut n = [0u8; 24];
        OsRng.fill_bytes(&mut n);
        let ct = aead.encrypt(XNonce::from_slice(&n), Payload { msg: plaintext, aad }).expect("seal");
        let mut out = n.to_vec();
        out.extend_from_slice(&ct);
        out
    }

    fn open(kr: &[u8], sealed: &[u8], aad: &[u8]) -> Vec<u8> {
        let aead = XChaCha20Poly1305::new(Key::from_slice(kr));
        let (n, ct) = sealed.split_at(24);
        aead.decrypt(XNonce::from_slice(n), Payload { msg: ct, aad }).expect("open")
    }

    fn write_record(&mut self, record_id: &str, pii_json: &str, policy: &[String]) -> LedgerEntry {
        let mut kr = [0u8; 32];
        OsRng.fill_bytes(&mut kr);
        let aad = Self::aad(record_id, policy);
        let sealed = Self::seal(&kr, pii_json.as_bytes(), &aad);
        let blob_hash = blake3::hash(&sealed).to_hex().to_string();
        let key_ref = self.kms.wrap_and_store(record_id, &kr);
        self.blob_store.insert(record_id.to_string(), sealed);
        self.ledger.append_anchor(record_id, &blob_hash, policy, &key_ref)
    }

    fn read_record(&self, record_id: &str, policy: &[String]) -> String {
        let kr = self.kms.unwrap(record_id).expect("record key missing (erased?)");
        let sealed = self.blob_store.get(record_id).expect("blob missing");
        let aad = Self::aad(record_id, policy);
        let pt = Self::open(&kr, sealed, &aad);
        String::from_utf8(pt).unwrap()
    }

    fn read_proof(&self, record_id: &str) -> bool {
        let sealed = self.blob_store.get(record_id).expect("blob");
        let h = blake3::hash(sealed).to_hex().to_string();
        self.ledger.last_anchor(record_id).map(|a| a.blob_hash.as_deref() == Some(&h)).unwrap_or(false)
    }

    fn erase_record(&mut self, record_id: &str, lawful_basis: &str, issuer: &str) -> ErasureReceipt {
        let anchor = self.ledger.last_anchor(record_id).expect("no anchor");
        self.kms.destroy(record_id);
        let pubkey = VerifyingKey::from(&self.signer);
        let pub_b64 = B64.encode(pubkey.to_bytes());

        let mut tmp = ErasureReceipt {
            record_id: record_id.to_string(),
            anchor_blob_hash: anchor.blob_hash.clone().unwrap(),
            key_ref: anchor.key_ref.clone().unwrap(),
            lawful_basis: lawful_basis.to_string(),
            ts: iso_now(),
            issuer: issuer.to_string(),
            pubkey: pub_b64,
            signature: String::new(),
        };
        let unsigned = tmp.unsigned_map();
        let msg = canonical_bytes(&unsigned);
        let sig = self.signer.sign(&msg);
        tmp.signature = B64.encode(sig.to_bytes());

        self.ledger.append_receipt_digest(record_id, &msg);
        tmp
    }

    fn verify_receipt(ledger: &Ledger, receipt: &ErasureReceipt) {
        // Rebuild unsigned map deterministically
        let unsigned = receipt.unsigned_map();
        let msg = canonical_bytes(&unsigned);
        // 1) Signature check
        let pk = VerifyingKey::from_bytes(&B64.decode(receipt.pubkey.as_bytes()).unwrap()).unwrap();
        pk.verify(&msg, &ed25519_dalek::Signature::from_bytes(&B64.decode(receipt.signature.as_bytes()).unwrap()).unwrap())
            .expect("invalid receipt signature");
        // 2) Anchoring check
        let digest = blake3::hash(&msg).to_hex().to_string();
        let anchored = ledger.entries.iter().any(|e|
            e.type_str == "receipt" && e.record_id == receipt.record_id && e.receipt_digest.as_deref() == Some(&digest)
        );
        assert!(anchored, "receipt not anchored");
    }
}

fn main() {
    let mut demo = Demo::new();
    let record_id = "user-123";
    let policy = vec!["gdpr".to_string(), "pii".to_string(), "consent".to_string()];

    println!("→ Write:");
    let anchor = demo.write_record(record_id, r#"{"name":"Ada","email":"ada@example.com"}"#, &policy);
    println!("{}", serde_json::to_string_pretty(&anchor).unwrap());

    println!("\n→ Read (pre-erasure):");
    println!("{}", demo.read_record(record_id, &policy));

    println!("\n→ ReadProof (pre-erasure): {}", demo.read_proof(record_id));

    println!("\n→ Erase by destroying per-record key:");
    let receipt = demo.erase_record(record_id, "GDPR Art.17(1) – consent withdrawn", "DemoService v1");
    println!("{}", serde_json::to_string_pretty(&receipt).unwrap());

    println!("\n→ Verify receipt:");
    Demo::verify_receipt(&demo.ledger, &receipt);
    println!("Receipt signature + anchoring: OK");

    println!("\n→ Read (post-erasure, expected failure):");
    let after = std::panic::catch_unwind(|| demo.read_record(record_id, &policy));
    if after.is_err() {
        println!("Decryption failed as expected: key has been destroyed");
    }

    println!("\n→ ReadProof (ciphertext still anchored): {}", demo.read_proof(record_id));
}

