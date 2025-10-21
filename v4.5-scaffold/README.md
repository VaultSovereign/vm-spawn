# VaultMesh v4.5 — Ritual Scaffold

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
  cargo run -p vm-cli -- verify --id <RECEIPT_ID>
