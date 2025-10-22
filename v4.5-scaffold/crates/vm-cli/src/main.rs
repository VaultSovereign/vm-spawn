use anyhow::{Context, Result, anyhow};
use clap::{CommandFactory, Parser, Subcommand, ValueEnum};
use miette::{IntoDiagnostic, miette};
use std::{fs, path::PathBuf};
use vm_core::{
    canonical::to_jcs_bytes,
    types::{Artifact, Receipt},
};
use vm_remembrancer::ReceiptStore;

#[derive(Parser)]
#[command(name = "vaultmesh")]
#[command(about = "VaultMesh Covenant Memory — Sovereign Rust CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Record {
        #[arg(long)]
        component: String,
        #[arg(long)]
        version: String,
        #[arg(long)]
        artifact: PathBuf,
        #[arg(long, default_value = "./vaultmesh.db")]
        store: String,
        #[arg(long)]
        pgp_key: Option<PathBuf>,
        #[arg(long)]
        pgp_password: Option<String>,
        #[arg(long)]
        pgp_cert: Option<PathBuf>,
        #[arg(long)]
        tsa_url: Option<String>,
    },
    Query {
        #[arg(long)]
        component: String,
        #[arg(long, default_value = "./vaultmesh.db")]
        store: String,
    },
    Verify {
        #[arg(long)]
        id: String,
        #[arg(long, default_value = "./vaultmesh.db")]
        store: String,
        #[arg(long)]
        pgp_cert: Option<PathBuf>,
    },
    Completions {
        #[arg(value_enum)]
        shell: Shell,
    },
    Manpage,
}

#[derive(Copy, Clone, ValueEnum)]
#[allow(clippy::enum_variant_names)]
enum Shell {
    Bash,
    Zsh,
    Fish,
    PowerShell,
    Elvish,
}

fn sha256_of(b: &[u8]) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(b);
    h.finalize().into()
}

fn now() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
}

fn main() -> miette::Result<()> {
    if let Err(e) = real_main() {
        return Err(miette!("{e:?}"));
    }
    Ok(())
}

fn real_main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Record {
            component,
            version,
            artifact,
            store,
            pgp_key,
            pgp_password,
            pgp_cert,
            tsa_url,
        } => {
            #[cfg(not(feature = "pgp"))]
            {
                let _ = (&pgp_key, &pgp_password, &pgp_cert);
            }
            #[cfg(not(feature = "tsa"))]
            {
                let _ = &tsa_url;
            }
            let bytes = fs::read(&artifact).with_context(|| format!("read {:?}", artifact))?;
            let sha = sha256_of(&bytes);
            #[allow(unused_mut)]
            let mut rec = Receipt {
                id: Receipt::make_id(&component, &version, &sha),
                component,
                version,
                artifact: Artifact {
                    sha256: sha,
                    gpg_signature: None,
                    rfc3161_token: None,
                    merkle_proof: None,
                },
                timestamp_utc: now(),
                context: serde_json::json!({"path": artifact}),
            };
            #[cfg(feature = "pgp")]
            let jcs = to_jcs_bytes(&rec)?;
            #[cfg(any(feature = "pgp", feature = "tsa"))]
            if let serde_json::Value::Object(ref mut ctx) = rec.context {
                #[cfg(feature = "pgp")]
                {
                    use vm_crypto::pgp;
                    if let Some(key_path) = pgp_key.as_ref() {
                        let key_bytes = fs::read(key_path)
                            .with_context(|| format!("load pgp key {key_path:?}"))?;
                        let cert = pgp::import_cert(&key_bytes)
                            .context("parse operator PGP certificate")?;
                        let sig = pgp::sign_detached(&cert, pgp_password.as_deref(), &jcs)?;
                        if !sig.is_empty() {
                            rec.artifact.gpg_signature = Some(sig);
                            let public_bytes = if let Some(cert_path) = pgp_cert.as_ref() {
                                fs::read(cert_path)
                                    .with_context(|| format!("load pgp cert {cert_path:?}"))?
                            } else {
                                pgp::export_cert(&cert)?
                            };
                            let public_str = String::from_utf8(public_bytes)
                                .context("PGP certificate is not valid UTF-8")?;
                            ctx.insert(
                                "pgp_cert".to_string(),
                                serde_json::Value::String(public_str),
                            );
                        }
                    }
                }

                #[cfg(feature = "tsa")]
                {
                    use vm_crypto::tsa;
                    let url = tsa_url.as_deref().unwrap_or(tsa::FREETSA_URL);
                    let tsr = tsa::timestamp_request(url, &rec.artifact.sha256)?;
                    if !tsr.is_empty() {
                        rec.artifact.rfc3161_token = Some(tsr);
                        ctx.insert(
                            "tsa_url".to_string(),
                            serde_json::Value::String(url.to_string()),
                        );
                    }
                }
            }
            #[cfg(feature = "sqlite")]
            {
                use vm_remembrancer::sqlite_store::SqliteStore;
                let mut s = SqliteStore::open(&store)?;
                s.put(&rec)?;
            }
            #[cfg(all(not(feature = "sqlite"), feature = "redb"))]
            {
                use vm_remembrancer::redb_store::RedbStore;
                let mut s = RedbStore::open(&store)?;
                s.put(&rec)?;
            }
            println!("{}", rec.id);
        }
        Commands::Query { component, store } => {
            #[cfg(feature = "sqlite")]
            {
                use vm_remembrancer::sqlite_store::SqliteStore;
                let s = SqliteStore::open(&store)?;
                for r in s.by_component(&component)? {
                    println!("{} {} {}", r.id, r.version, r.timestamp_utc);
                }
            }
            #[cfg(all(not(feature = "sqlite"), feature = "redb"))]
            {
                use vm_remembrancer::redb_store::RedbStore;
                let s = RedbStore::open(&store)?;
                for r in s.by_component(&component)? {
                    println!("{} {} {}", r.id, r.version, r.timestamp_utc);
                }
            }
        }
        Commands::Verify { id, store, pgp_cert } => {
            #[cfg(not(feature = "pgp"))]
            {
                let _ = &pgp_cert;
            }
            #[cfg(feature = "sqlite")]
            {
                use vm_remembrancer::sqlite_store::SqliteStore;
                let s = SqliteStore::open(&store)?;
                if let Some(r) = s.get(&id)? {
                    let a = to_jcs_bytes(&r)?;
                    let b = to_jcs_bytes(&serde_json::from_slice::<Receipt>(&a)?)?;
                    if a != b {
                        eprintln!("JCS not stable");
                    }
                    #[cfg(feature = "pgp")]
                    if let Some(sig) = r.artifact.gpg_signature.as_ref() {
                        use vm_crypto::pgp;
                        let cert_bytes = if let Some(cert_path) = pgp_cert.as_ref() {
                            Some(
                                fs::read(cert_path)
                                    .with_context(|| format!("load pgp cert {:?}", cert_path))?,
                            )
                        } else if let Some(serde_json::Value::String(armor)) =
                            r.context.get("pgp_cert")
                        {
                            Some(armor.as_bytes().to_vec())
                        } else {
                            None
                        };
                        if let Some(cert_data) = cert_bytes {
                            let cert =
                                pgp::import_cert(&cert_data).context("parse stored PGP cert")?;
                            if !pgp::verify_detached(&cert, sig, &a)? {
                                eprintln!("PGP verify: FAIL");
                            }
                        } else {
                            eprintln!("PGP verify: SKIPPED (no certificate)");
                        }
                    }
                    #[cfg(not(feature = "pgp"))]
                    if r.artifact.gpg_signature.is_some() {
                        eprintln!("PGP verify: SKIPPED (feature disabled)");
                    }
                    #[cfg(feature = "tsa")]
                    if let Some(tsr) = r.artifact.rfc3161_token.as_ref() {
                        if !vm_crypto::tsa::verify_timestamp(tsr, &r.artifact.sha256)? {
                            eprintln!("TSA verify: FAIL");
                        }
                    }
                    #[cfg(not(feature = "tsa"))]
                    if r.artifact.rfc3161_token.is_some() {
                        eprintln!("TSA verify: SKIPPED (feature disabled)");
                    }
                    println!("OK");
                } else {
                    println!("not found");
                }
            }
            #[cfg(all(not(feature = "sqlite"), feature = "redb"))]
            {
                use vm_remembrancer::redb_store::RedbStore;
                let s = RedbStore::open(&store)?;
                if s.get(&id)?.is_some() {
                    println!("OK");
                } else {
                    println!("not found");
                }
            }
        }
        Commands::Completions { shell } => {
            use clap_complete::{generate, shells};
            use std::io;
            let mut cmd = Cli::command();
            let name = cmd.get_name().to_string();
            match shell {
                Shell::Bash => generate(shells::Bash, &mut cmd, name, &mut io::stdout()),
                Shell::Zsh => generate(shells::Zsh, &mut cmd, name, &mut io::stdout()),
                Shell::Fish => generate(shells::Fish, &mut cmd, name, &mut io::stdout()),
                Shell::PowerShell => {
                    generate(shells::PowerShell, &mut cmd, name, &mut io::stdout())
                }
                Shell::Elvish => generate(shells::Elvish, &mut cmd, name, &mut io::stdout()),
            }
        }
        Commands::Manpage => {
            use clap_mangen::Man;
            let cmd = Cli::command();
            let man = Man::new(cmd);
            man.render(&mut std::io::stdout().lock())
                .into_diagnostic()
                .map_err(|e| anyhow!(e.to_string()))?;
        }
    }
    Ok(())
}
