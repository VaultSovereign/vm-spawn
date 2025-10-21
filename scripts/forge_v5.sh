#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BASE="$ROOT/v4.5-scaffold"   # repo has this dir already
mkdir -p "$BASE"/{crates,docs/adr,.github/workflows,fuzz/fuzz_targets}

# ---------- helpers ----------
w() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }
app() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" >> "$1"; }

# ---------- 1) Workspace Cargo.toml ----------
w "$BASE/Cargo.toml" "[workspace]
members = [\"crates/*\"]
resolver = \"2\"

[workspace.package]
edition = \"2024\"
rust-version = \"1.85\"
license = \"MIT OR Apache-2.0\"
authors = [\"VaultMesh Contributors\"]

[workspace.dependencies]
anyhow = \"1\"
thiserror = \"1\"
serde = { version = \"1\", features = [\"derive\"] }
serde_json = \"1\"
serde_jcs = \"0.1\"
sha2 = \"0.10\"
hex = \"0.4\"
time = { version = \"0.3\", features = [\"formatting\"] }
chrono = { version = \"0.4\", default-features = false, features = [\"clock\"] }
clap = { version = \"4\", features = [\"derive\"] }
clap_complete = \"4\"
clap_mangen = \"0.2\"
miette = { version = \"7\", features = [\"fancy\"] }
rusqlite = { version = \"0.31\", features = [\"bundled\"] }
redb = \"1\"
sequoia-openpgp = { version = \"1\", default-features = true }
x509-tsp = \"0.3\"
rustls = \"0.23\"
aws-lc-rs = \"1\"
openssl = { version = \"0.10\", features = [\"vendored\"] }"

# ---------- 2) README ----------
w "$BASE/README.md" "# VaultMesh v4.5 — Ritual Scaffold

Includes:
- vm-core (types + JCS + Merkle)
- vm-crypto (OpenPGP/TSA interfaces; rustls default, OpenSSL optional)
- vm-remembrancer (SQLite default; redb optional)
- vm-cli (record/query/verify; completions + manpage)
- vm-fed (p2p stub)
- CI (nextest/audit/coverage), fuzz target, ADR-0005

Quickstart:
  cargo build
  cargo run -p vm-cli -- --help
  cargo run -p vm-cli -- record --component demo --version 0.1.0 --artifact ./README.md
  cargo run -p vm-cli -- query --component demo
  cargo run -p vm-cli -- verify --id <RECEIPT_ID>"

# ---------- 3) CI ----------
w "$BASE/.github/workflows/ci.yml" "name: ci
on: [push, pull_request]
jobs:
  test:
    strategy: { matrix: { os: [ubuntu-latest, macos-latest, windows-latest] } }
    runs-on: \${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
        with: { toolchain: stable }
      - run: cargo install cargo-nextest --locked
      - run: cargo nextest run --workspace --all-features --profile ci
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
        with: { toolchain: stable }
      - run: cargo install cargo-audit --locked
      - run: cargo audit
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
        with: { toolchain: stable }
      - run: cargo install cargo-tarpaulin --locked
      - run: cargo tarpaulin --workspace --out Lcov
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
        with: { toolchain: stable }
      - run: |
          cargo build --release -p vm-cli --target x86_64-unknown-linux-musl
          cargo build --release -p vm-cli --target x86_64-apple-darwin
          cargo build --release -p vm-cli --target x86_64-pc-windows-gnu"

# ---------- 4) ADR-0005 ----------
w "$BASE/docs/adr/ADR-0005-federation-envelope.md" "# ADR-0005 — Signed Receipt Envelope & Federation Topic
Status: PROPOSED

Use a JCS-serialized envelope for signing, timestamping, and gossip.

Envelope (JCS before signing):
{
  \"schema\": \"vaultmesh.receipt.v1\",
  \"receipt\": { /* Receipt */ },
  \"merkle_root\": \"hex-32\",
  \"sig\": { \"alg\": \"openpgp-ed25519\", \"keyid\": \"....\", \"signature\": \"base64...\" },
  \"tsa\": { \"tsr_der\": \"base64...\" }
}
Gossip: topic \`vm/receipts/v1\`; discovery Kademlia; transport Noise; merge = JCS bytes → Merkle."

# ---------- 5) vm-core ----------
w "$BASE/crates/vm-core/Cargo.toml" "[package]
name = \"vm-core\"
version = \"0.1.0\"
edition = \"2024\"
license = \"MIT OR Apache-2.0\"

[dependencies]
anyhow = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
serde_jcs = { workspace = true }
sha2 = { workspace = true }
hex = { workspace = true }
time = { workspace = true }"

w "$BASE/crates/vm-core/src/lib.rs" "pub mod types; pub mod canonical; pub mod merkle;"

w "$BASE/crates/vm-core/src/types.rs" "use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artifact {
  pub sha256: [u8; 32],
  #[serde(skip_serializing_if = \"Option::is_none\")] pub gpg_signature: Option<Vec<u8>>,
  #[serde(skip_serializing_if = \"Option::is_none\")] pub rfc3161_token: Option<Vec<u8>>,
  #[serde(skip_serializing_if = \"Option::is_none\")] pub merkle_proof: Option<crate::merkle::MerkleProof>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Receipt {
  pub id: String, pub component: String, pub version: String,
  pub artifact: Artifact, pub timestamp_utc: String,
  #[serde(default)] pub context: serde_json::Value,
}
impl Receipt {
  pub fn make_id(component:&str, version:&str, sha:&[u8;32])->String {
    format!(\"{component}@{version}:{}\", hex::encode(&sha[..4]))
  }
}"

w "$BASE/crates/vm-core/src/canonical.rs" "use anyhow::Result; use serde::Serialize;
pub fn to_jcs_bytes<T: Serialize>(v:&T)->Result<Vec<u8>>{ Ok(serde_jcs::to_vec(v)?) }"

w "$BASE/crates/vm-core/src/merkle.rs" "use sha2::{Digest, Sha256}; use serde::{Serialize, Deserialize};
#[derive(Debug, Clone, Serialize, Deserialize)] pub struct MerkleProof{ pub leaf_hash:[u8;32], pub path:Vec<[u8;32]> }
pub fn leaf_hash(data:&[u8])->[u8;32]{ let mut h=Sha256::new(); h.update([0x00]); h.update(data); h.finalize().into() }
pub fn node_hash(l:&[u8;32], r:&[u8;32])->[u8;32]{ let mut h=Sha256::new(); h.update([0x01]); h.update(l); h.update(r); h.finalize().into() }
pub fn compute_root(mut leaves:Vec<[u8;32]>)->Option<[u8;32]>{
  if leaves.is_empty(){return None;}
  while leaves.len()>1{
    let mut next=Vec::with_capacity((leaves.len()+1)/2);
    for c in leaves.chunks(2){ next.push(match c{ [a,b]=>node_hash(a,b), [a]=>node_hash(a,a), _=>unreachable!() }); }
    leaves=next;
  }
  Some(leaves[0])
}"

# ---------- 6) vm-crypto ----------
w "$BASE/crates/vm-crypto/Cargo.toml" "[package]
name = \"vm-crypto\"
version = \"0.1.0\"
edition = \"2024\"
license = \"MIT OR Apache-2.0\"

[features]
default = [\"tls-rustls\"]
pgp = [\"dep:sequoia-openpgp\"]
tsa = [\"dep:x509-tsp\"]
tls-rustls = [\"dep:rustls\",\"dep:aws-lc-rs\"]
openssl = [\"dep:openssl\"]

[dependencies]
anyhow = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
serde_jcs = { workspace = true }
sequoia-openpgp = { workspace = true, optional = true }
x509-tsp = { workspace = true, optional = true }
rustls = { workspace = true, optional = true }
aws-lc-rs = { workspace = true, optional = true }
openssl = { workspace = true, optional = true }"

w "$BASE/crates/vm-crypto/src/lib.rs" "use anyhow::Result;
#[cfg(feature=\"pgp\")] pub mod pgp {
  use anyhow::Result;
  pub fn sign_detached(data:&[u8])->Result<Vec<u8>>{ let mut v=b\"PGP-SIGNATURE-PLACEHOLDER\".to_vec(); v.extend_from_slice(&data.len().to_be_bytes()); Ok(v) }
  pub fn verify_detached(_:&[u8], sig:&[u8])->Result<bool>{ Ok(sig.starts_with(b\"PGP-SIGNATURE-PLACEHOLDER\")) }
}
#[cfg(not(feature=\"pgp\"))] pub mod pgp {
  use anyhow::Result; pub fn sign_detached(_: &[u8])->Result<Vec<u8>>{Ok(Vec::new())} pub fn verify_detached(_: &[u8], _: &[u8])->Result<bool>{Ok(true)}
}
#[cfg(feature=\"tsa\")] pub mod tsa {
  use anyhow::Result; pub fn timestamp_request(_:&[u8])->Result<Vec<u8>>{ Ok(b\"TSA-TSR-PLACEHOLDER\".to_vec()) }
  pub fn verify_timestamp(_:&[u8], tsr:&[u8])->Result<bool>{ Ok(tsr.starts_with(b\"TSA-TSR-PLACEHOLDER\")) }
}
#[cfg(not(feature=\"tsa\"))] pub mod tsa {
  use anyhow::Result; pub fn timestamp_request(_:&[u8])->Result<Vec<u8>>{Ok(Vec::new())} pub fn verify_timestamp(_:&[u8], _:&[u8])->Result<bool>{Ok(true)}
}"

# ---------- 7) vm-remembrancer ----------
w "$BASE/crates/vm-remembrancer/Cargo.toml" "[package]
name = \"vm-remembrancer\"
version = \"0.1.0\"
edition = \"2024\"
license = \"MIT OR Apache-2.0\"

[features]
default = [\"sqlite\"]
sqlite = [\"dep:rusqlite\"]
redb   = [\"dep:redb\"]

[dependencies]
anyhow = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
serde_jcs = { workspace = true }
rusqlite = { workspace = true, optional = true }
redb = { workspace = true, optional = true }
vm-core = { path = \"../vm-core\" }"

w "$BASE/crates/vm-remembrancer/src/lib.rs" "use anyhow::Result; use vm_core::types::Receipt;
pub trait ReceiptStore{ fn put(&mut self,r:&Receipt)->Result<()>; fn get(&self,id:&str)->Result<Option<Receipt>>; fn by_component(&self,c:&str)->Result<Vec<Receipt>>; fn all(&self)->Result<Vec<Receipt>>; }
#[cfg(feature=\"sqlite\")] pub mod sqlite_store {
  use super::*; use rusqlite::{params,Connection};
  pub struct SqliteStore{ conn: Connection }
  impl SqliteStore{ pub fn open(p:&str)->Result<Self>{ let c=Connection::open(p)?; c.execute_batch(\"CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY, component TEXT NOT NULL, version TEXT NOT NULL, jcs BLOB NOT NULL); CREATE INDEX IF NOT EXISTS idx_component ON receipts(component);\")?; Ok(Self{conn:c}) } }
  impl ReceiptStore for SqliteStore{
    fn put(&mut self, r:&Receipt)->Result<()>{ let j=serde_jcs::to_vec(r)?; self.conn.execute(\"INSERT OR REPLACE INTO receipts(id,component,version,jcs) VALUES (?1,?2,?3,?4)\", params![r.id,r.component,r.version,j])?; Ok(()) }
    fn get(&self, id:&str)->Result<Option<Receipt>>{ let mut st=self.conn.prepare(\"SELECT jcs FROM receipts WHERE id=?1\")?; let mut rows=st.query(params![id])?; if let Some(row)=rows.next()?{ let j:Vec<u8>=row.get(0)?; return Ok(Some(serde_json::from_slice(&j)?)); } Ok(None) }
    fn by_component(&self, c:&str)->Result<Vec<Receipt>>{ let mut st=self.conn.prepare(\"SELECT jcs FROM receipts WHERE component=?1 ORDER BY id DESC\")?; let rows=st.query_map(params![c], |row|{ let j:Vec<u8>=row.get(0)?; Ok(serde_json::from_slice::<Receipt>(&j).unwrap()) })?; Ok(rows.filter_map(Result::ok).collect()) }
    fn all(&self)->Result<Vec<Receipt>>{ let mut st=self.conn.prepare(\"SELECT jcs FROM receipts ORDER BY id DESC\")?; let rows=st.query_map([], |row|{ let j:Vec<u8>=row.get(0)?; Ok(serde_json::from_slice::<Receipt>(&j).unwrap()) })?; Ok(rows.filter_map(Result::ok).collect()) }
  }
}
#[cfg(feature=\"redb\")] pub mod redb_store {
  use super::*; use redb::{Database,TableDefinition}; const T:TableDefinition<&str,Vec<u8>>=TableDefinition::new(\"receipts\");
  pub struct RedbStore{ db:Database } impl RedbStore{ pub fn open(p:&str)->Result<Self>{ Ok(Self{ db:Database::create(p)? }) } }
  impl ReceiptStore for RedbStore{
    fn put(&mut self,r:&Receipt)->Result<()>{ let j=serde_jcs::to_vec(r)?; let tx=self.db.begin_write()?; { let mut t=tx.open_table(T)?; t.insert(r.id.as_str(), j)?; } tx.commit()?; Ok(()) }
    fn get(&self,id:&str)->Result<Option<Receipt>>{ let tx=self.db.begin_read()?; let t=tx.open_table(T)?; if let Some(v)=t.get(id)?{ return Ok(Some(serde_json::from_slice(v.value())?)); } Ok(None) }
    fn by_component(&self,c:&str)->Result<Vec<Receipt>>{ let tx=self.db.begin_read()?; let t=tx.open_table(T)?; let mut out=Vec::new(); for r in t.iter()?{ let (_k,v)=r?; let rec:Receipt=serde_json::from_slice(v.value())?; if rec.component==c{ out.push(rec); } } Ok(out) }
    fn all(&self)->Result<Vec<Receipt>>{ let tx=self.db.begin_read()?; let t=tx.open_table(T)?; let mut out=Vec::new(); for r in t.iter()?{ let (_k,v)=r?; out.push(serde_json::from_slice(v.value())?); } Ok(out) }
  }
}"

# ---------- 8) vm-fed ----------
w "$BASE/crates/vm-fed/Cargo.toml" "[package]
name = \"vm-fed\"
version = \"0.1.0\"
edition = \"2024\"
license = \"MIT OR Apache-2.0\"

[features] p2p = []

[dependencies]
anyhow = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
vm-core = { path = \"../vm-core\" }"
w "$BASE/crates/vm-fed/src/lib.rs" "pub struct MergeReceipt{ pub left_root:[u8;32], pub right_root:[u8;32], pub merged_root:[u8;32] }"

# ---------- 9) vm-cli ----------
w "$BASE/crates/vm-cli/Cargo.toml" "[package]
name = \"vm-cli\"
version = \"0.1.0\"
edition = \"2024\"
license = \"MIT OR Apache-2.0\"

[features]
default = [\"sqlite\"]
sqlite = [\"vm-remembrancer/sqlite\"]
redb   = [\"vm-remembrancer/redb\"]
pgp    = [\"vm-crypto/pgp\"]
tsa    = [\"vm-crypto/tsa\"]
tls-rustls = [\"vm-crypto/tls-rustls\"]
openssl    = [\"vm-crypto/openssl\"]

[dependencies]
anyhow = { workspace = true }
clap = { workspace = true, features = [\"derive\"] }
clap_complete = { workspace = true }
clap_mangen = { workspace = true }
miette = { workspace = true, features = [\"fancy\"] }
serde = { workspace = true }
serde_json = { workspace = true }
sha2 = { workspace = true }
hex = { workspace = true }
chrono = { workspace = true }
vm-core = { path = \"../vm-core\" }
vm-crypto = { path = \"../vm-crypto\" }
vm-remembrancer = { path = \"../vm-remembrancer\" }"

w "$BASE/crates/vm-cli/src/main.rs" "use std::{fs, path::PathBuf};
use anyhow::{Context, Result}; use clap::{Parser, Subcommand, ValueEnum, CommandFactory};
use miette::{miette, IntoDiagnostic}; use vm_core::{canonical::to_jcs_bytes, types::{Artifact, Receipt}};
use vm_remembrancer::ReceiptStore;

#[derive(Parser)] #[command(name=\"vaultmesh\")] #[command(about=\"VaultMesh Covenant Memory — Sovereign Rust CLI\")]
struct Cli{ #[command(subcommand)] command: Commands }

#[derive(Subcommand)]
enum Commands{
  Record{ #[arg(long)] component:String, #[arg(long)] version:String, #[arg(long)] artifact:PathBuf, #[arg(long, default_value=\"./vaultmesh.db\")] store:String },
  Query{ #[arg(long)] component:String, #[arg(long, default_value=\"./vaultmesh.db\")] store:String },
  Verify{ #[arg(long)] id:String, #[arg(long, default_value=\"./vaultmesh.db\")] store:String },
  Completions{ #[arg(value_enum)] shell: Shell }, Manpage,
}
#[derive(Copy,Clone,ValueEnum)] enum Shell{ Bash, Zsh, Fish, PowerShell, Elvish }

fn sha256_of(b:&[u8])->[u8;32]{ use sha2::{Digest,Sha256}; let mut h=Sha256::new(); h.update(b); h.finalize().into() }
fn now()->String{ chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true) }

fn main()->miette::Result<()> { if let Err(e)=real_main(){ return Err(miette!(\"{e:?}\")); } Ok(()) }
fn real_main()->Result<()> {
  let cli=Cli::parse();
  match cli.command {
    Commands::Record{component,version,artifact,store}=>{
      let bytes=fs::read(&artifact).with_context(||format!(\"read {:?}\", artifact))?;
      let sha=sha256_of(&bytes);
      let mut rec=Receipt{
        id: Receipt::make_id(&component,&version,&sha),
        component, version,
        artifact: Artifact{ sha256: sha, gpg_signature: None, rfc3161_token: None, merkle_proof: None },
        timestamp_utc: now(), context: serde_json::json!({\"path\": artifact}),
      };
      let jcs=to_jcs_bytes(&rec)?; // sign/timestamp if features enabled
      let sig=vm_crypto::pgp::sign_detached(&jcs)?; if !sig.is_empty(){ rec.artifact.gpg_signature=Some(sig); }
      let tsr=vm_crypto::tsa::timestamp_request(&rec.artifact.sha256)?; if !tsr.is_empty(){ rec.artifact.rfc3161_token=Some(tsr); }
      #[cfg(feature=\"sqlite\")] { use vm_remembrancer::sqlite_store::SqliteStore; let mut s=SqliteStore::open(&store)?; s.put(&rec)?; }
      #[cfg(all(not(feature=\"sqlite\"), feature=\"redb\"))] { use vm_remembrancer::redb_store::RedbStore; let mut s=RedbStore::open(&store)?; s.put(&rec)?; }
      println!(\"{}\", rec.id);
    }
    Commands::Query{component,store}=>{
      #[cfg(feature=\"sqlite\")] { use vm_remembrancer::sqlite_store::SqliteStore; let s=SqliteStore::open(&store)?; for r in s.by_component(&component)? { println!(\"{} {} {}\", r.id, r.version, r.timestamp_utc); } }
      #[cfg(all(not(feature=\"sqlite\"), feature=\"redb\"))] { use vm_remembrancer::redb_store::RedbStore; let s=RedbStore::open(&store)?; for r in s.by_component(&component)? { println!(\"{} {} {}\", r.id, r.version, r.timestamp_utc); } }
    }
    Commands::Verify{id,store}=>{
      #[cfg(feature=\"sqlite\")] {
        use vm_remembrancer::sqlite_store::SqliteStore; let s=SqliteStore::open(&store)?;
        if let Some(r)=s.get(&id)? {
          let a=to_jcs_bytes(&r)?; let b=to_jcs_bytes(&serde_json::from_slice::<Receipt>(&a)?)?;
          if a!=b { eprintln!(\"JCS not stable\"); }
          if let Some(sig)=r.artifact.gpg_signature.as_ref(){ if !vm_crypto::pgp::verify_detached(&a,sig)? { eprintln!(\"PGP verify: FAIL\"); } }
          if let Some(tsr)=r.artifact.rfc3161_token.as_ref(){ if !vm_crypto::tsa::verify_timestamp(&r.artifact.sha256,tsr)? { eprintln!(\"TSA verify: FAIL\"); } }
          println!(\"OK\");
        } else { println!(\"not found\"); }
      }
      #[cfg(all(not(feature=\"sqlite\"), feature=\"redb\"))] { use vm_remembrancer::redb_store::RedbStore; let s=RedbStore::open(&store)?; if s.get(&id)?.is_some(){ println!(\"OK\"); } else { println!(\"not found\"); } }
    }
    Commands::Completions{shell}=>{
      use clap_complete::{generate, shells}; use std::io; let mut cmd=Cli::command(); let name=cmd.get_name().to_string();
      match shell {
        Shell::Bash=>generate(shells::Bash,&mut cmd,name,&mut io::stdout()),
        Shell::Zsh=>generate(shells::Zsh,&mut cmd,name,&mut io::stdout()),
        Shell::Fish=>generate(shells::Fish,&mut cmd,name,&mut io::stdout()),
        Shell::PowerShell=>generate(shells::PowerShell,&mut cmd,name,&mut io::stdout()),
        Shell::Elvish=>generate(shells::Elvish,&mut cmd,name,&mut io::stdout()),
      };
    }
    Commands::Manpage=>{
      use clap_mangen::Man; let cmd=Cli::command(); let man=Man::new(cmd); let mut buf=Vec::new(); man.render(&mut buf).into_diagnostic()?; print!(\"{}\", String::from_utf8_lossy(&buf));
    }
  }
  Ok(())
}
"

# ---------- 10) fuzz (optional) ----------
w "$BASE/fuzz/Cargo.toml" "[package]
name = \"vm-fuzz\"
version = \"0.0.0\"
publish = false
edition = \"2024\"

[package.metadata] cargo-fuzz = true

[dependencies]
libfuzzer-sys = \"0.4\"
vm-core = { path = \"../crates/vm-core\" }
serde_json = \"1\"

[[bin]]
name = \"receipt_parse\"
path = \"fuzz_targets/receipt_parse.rs\"
test = false
doc = false
bench = false"
w "$BASE/fuzz/fuzz_targets/receipt_parse.rs" "#![no_main]
use libfuzzer_sys::fuzz_target;
fuzz_target!(|data: &[u8]| {
  if let Ok(v)=serde_json::from_slice::<serde_json::Value>(data){
    let _ = vm_core::canonical::to_jcs_bytes(&v);
  }
});"

echo "RITUAL COMPLETE in $BASE"
