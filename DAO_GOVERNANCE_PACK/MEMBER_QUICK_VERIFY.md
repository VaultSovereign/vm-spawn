# Member Quick-Verify (3 steps)

Use this guide to independently verify the Genesis v4.1 artifact after the DAO vote.

## Prerequisites

- Git and GPG installed
- OpenSSL (for timestamp verification)
- Clone of the VaultMesh repository

## Verification Steps

### 1. Download Genesis Assets

From the [v4.1-genesis release](https://github.com/<org>/<repo>/releases/tag/v4.1-genesis):
- `dist/genesis.tar.gz`
- `dist/genesis.tar.gz.asc` (GPG signature)
- `dist/genesis.tar.gz.tsr` (RFC 3161 timestamp)
- `ops/certs/cache/public.ca.pem` (TSA root CA)
- `ops/certs/cache/public.tsa.crt` (TSA signer cert)

### 2. Verify GPG Signature

```bash
gpg --verify dist/genesis.tar.gz.asc dist/genesis.tar.gz
```

**Expected output:**
```
gpg: Signature made [DATE]
gpg: Good signature from "DAO Operator <operator@dao.org>"
```

### 3. Verify RFC 3161 Timestamp (Public TSA)

```bash
openssl ts -verify -in dist/genesis.tar.gz.tsr -data dist/genesis.tar.gz \
  -CAfile ops/certs/cache/public.ca.pem -untrusted ops/certs/cache/public.tsa.crt
```

**Expected output:**
```
Verification: OK
```

### 4. Inspect Timestamp Details (Optional)

```bash
openssl ts -reply -in dist/genesis.tar.gz.tsr -text
```

Shows: timestamp, TSA policy OID, serial number, and hash algorithm.

## What This Proves

- **Authenticity:** The artifact was signed by the DAO operator's GPG key
- **Existence:** The artifact existed at a specific time (per RFC 3161 TSA)
- **Integrity:** The artifact hash matches what was signed and timestamped

## Receipts Index

Current Merkle root and all receipts are available at:
- **Local:** `docs/receipts/index.md`
- **Online:** [GitHub Pages receipts index](https://<org>.github.io/<repo>/receipts/)

## Questions?

- See the [Operator Runbook](./operator-runbook.md) for detailed procedures
- Read the [Snapshot Proposal](./snapshot-proposal.md) for governance context
- Review the [Pack README](./README.md) for quick start guides

---

**Blockchain proves that we decided; VaultMesh proves why/how/when.**

🜄 Astra inclinant, sed non obligant.

