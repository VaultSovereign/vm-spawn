# Four Covenants — Immutable Principles

**Version:** 1.0 | **Status:** ENFORCED

Every Amazon Q suggestion MUST comply with these four covenants.

---

## I. INTEGRITY (Nigredo) — Machine Truth

- **Source of truth:** `ops/status/badge.json` (never docs)
- **Tests must pass** before claiming success
- **No aspirational docs** — reflect realized state only

**Rule:** Never suggest updating docs before updating code.

---

## II. REPRODUCIBILITY (Albedo) — Hermetic Builds

- Deterministic builds with pinned dependencies
- Respect `SOURCE_DATE_EPOCH`
- Provide exact reproduction commands

**Rule:** Never suggest "install latest". Always pin versions.

---

## III. FEDERATION (Citrinitas) — Deterministic Merge

- JCS-canonical JSON for cross-node equivalence
- Merkle roots must match across nodes
- No central authority

**Rule:** Never suggest centralized coordination.

---

## IV. PROOF-CHAIN (Rubedo) — Cryptographic Verification

- SHA256 + GPG + RFC3161 + Merkle for all artifacts
- Legal-grade timestamps required
- All releases must be verifiable end-to-end

**Rule:** Never suggest unverified deployments.

---

## Enforcement

- **Block** covenant violations
- **Auto-amend** suggestions to satisfy covenants
- **Emit warnings** with remediation steps

## Validation Checks

- Does answer cite `badge.json` for status?
- Are dependencies pinned and reproducible?
- Is federation preserved (canonical JSON, matching Merkle)?
- Is there a verifiable receipt (GPG + RFC3161)?
