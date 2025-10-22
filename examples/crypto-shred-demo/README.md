# Crypto‑Shredding Demos (Python & Rust)

Compact, runnable demos implementing:

- per‑record (envelope) keys
- immutable anchor log (append‑only)
- erasure by key destruction
- signed erasure receipt + verification

These are intentionally minimal and in‑memory for quick scanning/porting. They do not touch VaultMesh Layer 2 state (no receipts written) and are safe to run locally.

## Python

Requirements: Python 3.10+

Install deps:

```bash
pip install cryptography blake3
```

Run:

```bash
python examples/crypto-shred-demo/python/crypto_shred_demo.py
```

## Rust

Requirements: Rust toolchain (cargo) installed.

Build and run:

```bash
cd examples/crypto-shred-demo/rust
cargo run
```

## What it shows

1. On write: DEK per record, XChaCha20‑Poly1305 (AAD binds record_id|policy), BLAKE3 anchor in an append‑only in‑memory ledger, DEK wrapped under an in‑memory KEK.
2. On erasure: destroy only the wrapped DEK entry (ciphertext remains), issue an Ed25519‑signed erasure receipt, anchor its digest on the ledger.
3. Verification: receipt signature check + digest anchoring, “ReadProof” confirms ciphertext still matches its anchor; decryption fails post‑erasure.

