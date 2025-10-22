# vm-spawn Rust v4.5 scaffold

## Quickstart
```bash
cd v4.5-scaffold/rust
cargo build

# Run the demo server that verifies HTTP Message Signatures + receipts
cargo run -p vm-adapter-axum

# In another shell: run a tiny plan and POST a signed callback to the server
cargo run -p vm-cli -- run \
  --plan examples/mini.json \
  --callback http://127.0.0.1:3000/callback \
  --key examples/dev-ed25519.pem

# Preview the signed headers without sending a request
cargo run -p vm-cli -- run \
  --plan examples/mini.json \
  --callback http://127.0.0.1:3000/callback \
  --key examples/dev-ed25519.pem \
  --dry-run

# Verify a stored receipt
cargo run -p vm-cli -- verify --receipt target/receipts/last.json
```

Generate a dev key (PEM, PKCS#8 Ed25519):

```bash
openssl genpkey -algorithm Ed25519 -out examples/dev-ed25519.pem
```

The Axum adapter enforces nonce-based replay protection and a ±120-second clock
window by default. The CLI generates a fresh UUID-backed nonce and embeds the
`created` timestamp when signing requests so verified callbacks succeed out of
the box. Expect `401 Unauthorized` for signature tamper, `409 Conflict` for
replays, and `400 Bad Request` when headers are malformed or the message is
outside the allowed skew.
