use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use http::Request;
use reqwest::{header::HeaderMap as ReqwestHeaderMap, Url};
use serde::{Deserialize, Serialize};
use std::fs;
use time::OffsetDateTime;
use tracing::info;
use tracing_subscriber::EnvFilter;
use uuid::Uuid;
use vm_core::{Job, Op};
use vm_httpsig::{sign_request_with, KeyPair};
use vm_receipt::ReceiptBuilder;

#[derive(Parser)]
#[command(name = "vm-cli", version)]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Run a tiny plan and POST a signed callback with the receipt
    Run {
        #[arg(long)]
        plan: String,
        #[arg(long)]
        callback: String,
        #[arg(long, default_value = "examples/dev-ed25519.pem")]
        key: String,
        #[arg(long)]
        dry_run: bool,
    },
    /// Verify a stored receipt file
    Verify {
        #[arg(long)]
        receipt: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Plan {
    id: String,
    ops: Vec<Op>,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::new("info"))
        .init();
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Run {
            plan,
            callback,
            key,
            dry_run,
        } => run(plan, callback, key, dry_run).await,
        Cmd::Verify { receipt } => verify(receipt).await,
    }
}

async fn run(plan_path: String, callback: String, key_path: String, dry_run: bool) -> Result<()> {
    let plan: Plan = serde_json::from_str(&fs::read_to_string(&plan_path)?)?;
    let job = Job { id: plan.id.clone(), ops: plan.ops.clone() };

    // Execute
    let outcome = job.run().await?;
    info!("job outcome value={}", outcome.final_value);

    // Build a receipt
    let mut rb = ReceiptBuilder::default();
    rb.push_labeled("job_id", plan.id.as_bytes());
    rb.push_labeled("final_value", outcome.final_value.to_string().as_bytes());
    let receipt = rb.finalize()?;

    // Save receipt
    fs::create_dir_all("target/receipts")?;
    let out_path = "target/receipts/last.json";
    fs::write(out_path, serde_json::to_vec_pretty(&receipt)?)?;
    info!("wrote {}", out_path);

    // Prepare HTTP callback with signature
    let kp = KeyPair::from_pem_file(&key_path, "ed25519-1")?;
    let url = Url::parse(&callback)?;
    let body_bytes = serde_json::to_vec(&receipt)?;

    let mut req = Request::post(url.as_str())
        .header("content-type", "application/json")
        .body(body_bytes.clone())
        .map_err(|e| anyhow::anyhow!("Failed to create request: {}", e))?;

    let created = OffsetDateTime::now_utc().unix_timestamp();
    let nonce = format!("nonce-{}", Uuid::new_v4());
    sign_request_with(&mut req, &body_bytes, &kp, created, Some(&nonce))?;

    if dry_run {
        println!("--- Dry Run ---");
        println!("created: {}", created);
        println!("nonce: {}", nonce);
        for (name, value) in req.headers().iter() {
            println!("{}: {}", name, value.to_str().unwrap_or("<binary>"));
        }
        println!("Body ({} bytes)", body_bytes.len());
        println!("----------------");
        return Ok(());
    }

    // Send
    let client = reqwest::Client::new();
    let mut headers = ReqwestHeaderMap::new();
    for (name, value) in req.headers().iter() {
        headers.insert(name.clone(), value.clone());
    }
    let resp = client
        .post(url)
        .headers(headers)
        .body(body_bytes)
        .send()
        .await?;

    info!("callback status={} ", resp.status());
    Ok(())
}

async fn verify(path: String) -> Result<()> {
    let bytes = fs::read(&path).with_context(|| format!("reading {path}"))?;
    let rcpt: serde_json::Value = serde_json::from_slice(&bytes)?;
    println!("{}", serde_json::to_string_pretty(&rcpt)?);
    Ok(())
}
