# Proposal: Adopt the VaultMesh Remembrancer as the DAO's Cryptographic Memory Standard (Four Covenants v4.1 Genesis)

**Author:** [Your handle]  
**Category:** Governance / Operations / Security  
**Summary:** Adopt a machine-verifiable memory layer for all DAO decisions and artifacts using the Four Covenants: (I) Machine Truth, (II) Hermetic Reproducibility, (III) Deterministic Federation, (IV) Dual-Rail RFC 3161 Proofs. Execute a Genesis sealing ceremony and require receipts on future governance actions.

---

## 1) Abstract

Blockchains record that we decided; they don't preserve why, how, or when with strong guarantees. This proposal adopts VaultMesh Remembrancer to make the DAO's operational memory cryptographically provable:
- **Authenticity:** GPG signatures for decisions/artifacts
- **Existence in time:** RFC 3161 timestamps (dual TSA)
- **Integrity:** Merkle-audited receipts
- **Determinism:** Canonical federation merge semantics
- **Machine truth:** Test oracles as machine-readable JSON

We will seal a Genesis artifact, publish a receipts index, and require proof-bearing receipts on governance going forward.

---

## 2) Motivation

DAOs lose context in chats, docs, and turnover. Disputes arise later: "who approved this, when, why, and has it been altered?" Adopting a standard, tool-agnostic proof layer gives the DAO:
- **Audit readiness:** Court-portable evidence (signatures + timestamps)
- **Institutional memory:** Reasoning and evidence persist beyond contributors
- **Fork clarity:** History can't be rewritten; only extended
- **Automation:** Machine-readable test/status feeds for governance bots

---

## 3) Specification (what passes if YES)

### A. Establish Trust Anchors
- Designate `REMEMBRANCER_KEY_ID` (DAO multisig steward key or dedicated ops key)
- Configure dual TSAs (e.g., FreeTSA + enterprise TSA)

### B. Perform the Genesis Ceremony
- Generate `GENESIS` (tree hash at the adopted tag/commit)
- Create `GENESIS.yaml` with repo, commit, SOURCE_DATE_EPOCH, TSA details, operator key, and verification transcripts
- Sign and dual-timestamp `dist/genesis.tar.gz`
- Record a deployment receipt and publish the receipts index

### C. Enforce the Four Covenants

**1. Covenant I — Integrity (Machine Truth)**
- All test status emitted as `SMOKE_JSON` and published as `ops/status/badge.json`

**2. Covenant II — Reproducibility (Hermetic Builds)**
- Builds use commit-based `SOURCE_DATE_EPOCH`; base images pinned by digest; record content-addressable image ID

**3. Covenant III — Federation (Deterministic Merge)**
- Canonical JSON events (JCS-like), deterministic sort, Merkle root reconciliation; `MERGE_RECEIPT` for merges

**4. Covenant IV — Proof-Chain Independence (RFC 3161)**
- Dual-rail verification via `openssl ts -verify` with split CA/TSA certs and optional SPKI pinning

### D. Ongoing Requirement (from next cycle)
- Any governance artifact (e.g., policy docs, audits, deployments) must have a receipt: SHA-256, GPG signature, RFC 3161 timestamp(s), and inclusion in the Merkle-audited index
- Decisions recorded with `--chain_ref` (proposal/tx hash) to bind on-chain events to receipts

---

## 4) Execution Plan (operator steps)

These are the exact commands the ops steward will run upon proposal passing.

```bash
# 1) Configure TSAs (public + enterprise)
export REMEMBRANCER_TSA_URL_1="https://freetsa.org/tsr"
export REMEMBRANCER_TSA_CA_CERT_1="https://freetsa.org/files/cacert.pem"
export REMEMBRANCER_TSA_CERT_1="https://freetsa.org/files/tsa.crt"
export REMEMBRANCER_TSA_URL_2="<enterprise_tsa_url>"
export REMEMBRANCER_TSA_CA_CERT_2="<enterprise_root_ca_url>"
export REMEMBRANCER_TSA_CERT_2="<enterprise_tsa_signer_url>"
./ops/bin/tsa-bootstrap

# 2) Seal Genesis (creates GENESIS + GENESIS.yaml + dual timestamps + receipt)
export REMEMBRANCER_KEY_ID=<DAO_GPG_KEY_ID>
./ops/bin/genesis-seal
./ops/bin/rfc3161-verify dist/genesis.tar.gz
./ops/bin/receipts-site

# 3) Enforce machine truth & run covenants
./ops/bin/assert-tests-consistent
make covenant
```

---

## 5) Verification (any member can check)

### Signatures (authenticity)
```bash
gpg --verify dist/genesis.tar.gz.asc dist/genesis.tar.gz
```

### Timestamps (existence)
```bash
openssl ts -reply -in dist/genesis.tar.gz.tsr -text
openssl ts -verify -in dist/genesis.tar.gz.tsr -data dist/genesis.tar.gz \
  -CAfile ops/certs/cache/public.ca.pem -untrusted ops/certs/cache/public.tsa.crt
# (Repeat with enterprise CA/TSA for the second timestamp)
```

### Merkle audit (integrity)
```bash
./ops/bin/remembrancer verify-audit
```

### Machine truth (tests)
```bash
cat ops/status/badge.json
# => {"tests":{"pass":X,"total":Y,"pct":Z}}
```

---

## 6) Governance & On-Chain Binding

For each passed proposal or executed Safe transaction, ops records:

```bash
remembrancer record deploy \
  --component dao-governance \
  --version proposal-<N> \
  --sha256 <artifact_hash_if_any> \
  --evidence <file_or_uri> \
  --chain_ref "eip155:<chain_id>/tx:0x<tx_or_proposal_hash>"
```

Export a portable proof bundle when needed:

```bash
remembrancer export-proof <artifact_or_doc.tar.gz>
```

---

## 7) Risk Analysis

- **TSA outage/compromise:** Mitigated by dual TSAs; receipts annotate outages and alternate stamps
- **Key compromise:** Publish revocation receipt, rotate subkeys, re-sign recent receipts
- **Operational overhead:** Scripts are automated; verification commands are copy-pasteable for members
- **Adoption inertia:** Start with Genesis + receipts for major decisions; expand scope gradually

---

## 8) Costs

- **Minimal infra cost:** Timestamping is low-cost (FreeTSA + optional enterprise plan)
- **Operator time:** ~1–2 hours initial ceremony; minutes per decision thereafter
- **Tooling:** Uses standard OpenPGP and OpenSSL (no proprietary lock-in)

---

## 9) Success Criteria

- Genesis sealed with dual timestamps; receipts index published
- All new governance artifacts carry receipts (hash + GPG + RFC 3161)
- Covenant runner (`make covenant`) returns 0 in CI on main
- Any member can independently verify signatures, timestamps, and Merkle root using the commands above

---

## 10) Timeline

- **T+0–2 days:** Seal Genesis, publish receipts site
- **T+3–7 days:** Enforce receipts on new proposals and ops actions
- **T+30 days:** Report audit stats (N receipts, verification pass rate, any incidents)
- **T+60–90 days (optional):** Begin cross-DAO federation pilot

---

## 11) Voting

### Choices
- ✅ **Adopt VaultMesh Remembrancer (Four Covenants v4.1 Genesis)**
- ❌ **Do not adopt**

### Quorum / Threshold
- **Snapshot:** [Set your preferred quorum / approval threshold]
- **Tally / On-chain:** [Set your parameters to pass]

### Implementation
If YES passes, ops stewards execute the steps in Section 4 and post verification transcripts + links to the receipts index in the proposal's comments.

---

## 12) Appendices

### A. Minimal operator checklist
- TSA bootstrap → Genesis seal → Dual verification → Receipts site → Covenant runner green

### B. Example receipts index entry
- `docs/receipts/index.md` shows current Merkle root and a list of receipt SHA-256s with verification commands

### C. Contact
- Ops steward: [name/handle], GPG key: [fingerprint]

### D. Current State (Genesis v4.1)

**Merkle Root:** `d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea`

**Status:**
- ✅ Four Covenants infrastructure deployed
- ✅ Health checks: 16/16 passing
- ✅ Tests: 10/10 (100%)
- ✅ Federation merge operational
- ✅ Dual-TSA verification ready

**Commits:**
- `a7d97d0` - Four Covenants hardening (31 files)
- `74bc0dc` - Completion documentation
- `561d20b` - DAO Governance Pack

---

**Astra inclinant, sed non obligant.**  
**Nigredo → Albedo → Citrinitas → Rubedo.**

