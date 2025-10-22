# MIGRATION — v5.0 Sovereign Rust Core

**Date:** 2025-10-22
**Scope:** Proof serialization, CLI flags, feature gating

---

## 🔴 Breaking — MerkleProof shape change

**Old:**
```jsonc
{
  "leaf_hash": "<32b hex>",
  "path": ["<32b hex>", "..."]  // sibling hashes (no direction)
}
```

**New (v5.0):**
```jsonc
{
  "leaf_hash": "<32b hex>",
  "path": [
    { "sibling": "<32b hex>", "sibling_on_right": true | false },
    ...
  ]
}
```

**Why:** Proof verification must know whether the sibling is left or right to replay the tree correctly. The new `ProofStep { sibling, sibling_on_right }` prevents false negatives for right-hand leaves and eliminates prior panics.

### ✅ Action: Rebuild historical proofs

If you have persisted proofs:

1. Export receipt IDs that contain `artifact.merkle_proof`.
2. Recompute proofs against your ledger's canonical order.
3. Reserialize using the new `ProofStep` layout.
4. Verify with `vm-cli verify --id <RECEIPT_ID>`.

---

## 🛠️ CLI changes

### New flags (feature-gated)

* `--pgp-key <path>` — operator's secret key (Sequoia)
* `--pgp-password <string>` — optional passphrase
* `--pgp-cert <path>` — public cert to embed/verify
* `--tsa-url <url>` — TSA endpoint (default: FreeTSA)

**Behavior:**

* If `pgp`/`tsa` features are **disabled**, flags are accepted but **ignored**; CLI prints "SKIPPED (feature disabled)" and exits 0 without panics.
* If `pgp` is enabled, the exported cert is embedded in the receipt's `context.pgp_cert` unless provided via `--pgp-cert`.

---

## 🧩 Feature matrix

| Target      | Default Features                                                   | Notes                                                        |
| ----------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| Linux/macOS | `--all-features`                                                   | Requires `nettle`, `gmp`, `sqlite`, `pkg-config` system libs |
| Windows     | `--no-default-features --features vm-cli/sqlite,vm-cli/tls-rustls` | Skips `pgp/tsa` to avoid nettle/gmp toolchain                |

---

## 🔐 Supply chain policy (cargo-deny)

Allow: `MIT`, `Apache-2.0`, `BSD-3-Clause`, `ISC`, `Zlib`, plus **OpenSSL**, **Unicode-3.0**, **CDLA-Permissive-2.0**.
Deny: `GPL-3.0`, `AGPL-3.0`.
Yanked/unmaintained: warn. Vulnerabilities: deny.

---

## 🧪 Post-migration checks

```bash
# Format + lint
cargo fmt --all && cargo clippy --workspace --all-features --all-targets -- -D warnings

# Tests (Linux/macOS)
cargo nextest run --workspace --all-features

# Windows path
cargo build --workspace --no-default-features --features vm-cli/sqlite,vm-cli/tls-rustls

# Supply chain
cargo deny check
```

**Result:** Receipts verify cleanly; no panics; CI green.
