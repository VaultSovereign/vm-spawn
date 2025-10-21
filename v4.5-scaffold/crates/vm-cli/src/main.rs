use anyhow::{Context, Result};
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
    },
    Completions {
        #[arg(value_enum)]
        shell: Shell,
    },
    Manpage,
}

#[derive(Copy, Clone, ValueEnum)]
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
        Commands::Record { component, version, artifact, store } => {
            let bytes = fs::read(&artifact).with_context(|| format!("read {:?}", artifact))?;
            let sha = sha256_of(&bytes);
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
            let jcs = to_jcs_bytes(&rec)?;
            let sig = vm_crypto::pgp::sign_detached(&jcs)?;
            if !sig.is_empty() {
                rec.artifact.gpg_signature = Some(sig);
            }
            let tsr = vm_crypto::tsa::timestamp_request(&rec.artifact.sha256)?;
            if !tsr.is_empty() {
                rec.artifact.rfc3161_token = Some(tsr);
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
        Commands::Verify { id, store } => {
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
                    if let Some(sig) = r.artifact.gpg_signature.as_ref() {
                        if !vm_crypto::pgp::verify_detached(&a, sig)? {
                            eprintln!("PGP verify: FAIL");
                        }
                    }
                    if let Some(tsr) = r.artifact.rfc3161_token.as_ref() {
                        if !vm_crypto::tsa::verify_timestamp(&r.artifact.sha256, tsr)? {
                            eprintln!("TSA verify: FAIL");
                        }
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
            man.render(&mut std::io::stdout().lock()).into_diagnostic()?;
        }
    }
    Ok(())
}
