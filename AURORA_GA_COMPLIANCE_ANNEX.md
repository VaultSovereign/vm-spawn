# 🛡️ Aurora GA — NIST AI RMF & ISO/IEC 42001 Compliance Annex

**SOC-Style Control Mapping**  
**Version:** v1.0.0 (Aurora GA)  
**Date:** October 22, 2025  
**Audience:** Compliance, Audit, Governance

---

## Executive Summary

This annex maps **Aurora GA** technical controls to:

1. **NIST AI Risk Management Framework (AI RMF 1.0)** — Trustworthy AI governance
2. **ISO/IEC 42001:2023** — AI management system requirements

Aurora's **cryptographic provenance, policy enforcement, and observability** infrastructure provide **verifiable evidence** for compliance with AI governance frameworks.

---

## NIST AI RMF 1.0 Control Mapping

### GOVERN — Organizational Structures

| Function | Subcategory | Aurora Implementation | Evidence |
|----------|-------------|----------------------|----------|
| GOVERN 1.1 | Legal/regulatory requirements mapped | Treaty protocol enforces multi-stakeholder agreements | `docs/TREATY_PROTOCOL.md` |
| GOVERN 1.3 | AI risk management documented | Threat model + operational runbook | `THREAT_MODEL.md`, `ops/runbooks/AURORA_OPERATIONS.md` |
| GOVERN 2.1 | Accountability structures defined | Operator key registry + GPG signing | `ops/bin/remembrancer` (key: 6E4082C6A410F340) |
| GOVERN 3.1 | Risk tolerances documented | Policy constraints (quotas, regions, reputation) | `aurora-policy/src/vault_law.rs` |
| GOVERN 4.1 | AI system inventory maintained | Service catalog + Merkle audit log | `ops/data/remembrancer.db` |

### MAP — Context Establishment

| Function | Subcategory | Aurora Implementation | Evidence |
|----------|-------------|----------------------|----------|
| MAP 1.1 | AI system documentation | Architecture docs + ADRs | `v4.5-scaffold/docs/ARCHITECTURE.md` |
| MAP 1.2 | Categorization based on risk | DePIN federation (high-value coordination) | `THREAT_MODEL.md` (Section: Attack Vectors) |
| MAP 2.1 | Stakeholder engagement | Multi-provider federation + treaty templates | `docs/TREATY_PROTOCOL.md` |
| MAP 3.1 | AI capabilities documented | WASM policy engine specifications | `aurora-policy/README.md` |
| MAP 5.1 | Risks identified and documented | Threat model (Byzantine, Sybil, replay) | `THREAT_MODEL.md` |

### MEASURE — Metrics and Monitoring

| Function | Subcategory | Aurora Implementation | Evidence |
|----------|-------------|----------------------|----------|
| MEASURE 1.1 | AI system performance metrics | Prometheus exporters (fill rate, RTT, coverage) | `aurora-federation/src/metrics.rs` |
| MEASURE 1.2 | Risk metrics tracked | Policy violation rate, failover events | Grafana dashboard: `ops/grafana/aurora-ga.json` |
| MEASURE 2.1 | Bias testing conducted | Provider reputation thresholds | `aurora-policy/src/vault_law.rs` (reputation constraint) |
| MEASURE 2.3 | Privacy metrics tracked | DID-based authentication (no PII logging) | `aurora-federation/src/identity.rs` |
| MEASURE 3.1 | AI system monitoring operational | 24/7 Prometheus + Grafana + PagerDuty | `AURORA_STAGING_CANARY_QUICKSTART.md` |

### MANAGE — Risk Response

| Function | Subcategory | Aurora Implementation | Evidence |
|----------|-------------|----------------------|----------|
| MANAGE 1.1 | Risk treatment plans documented | Operational runbook + incident procedures | `ops/runbooks/AURORA_OPERATIONS.md` |
| MANAGE 1.2 | Risk treatments implemented | Nonce replay protection, ACK verification | `aurora-federation/src/nonce.rs`, `aurora-federation/src/ack.rs` |
| MANAGE 2.1 | Incidents documented | Receipts + Merkle audit trail | `ops/receipts/`, `ops/data/remembrancer.db` |
| MANAGE 2.2 | Incident response tested | Smoke test suite + failover scenarios | `make smoke-e2e`, `ops/bin/health-check` |
| MANAGE 3.1 | Change management operational | Git-based versioning + GPG signatures | `.git/`, `*.asc` artifacts |

---

## ISO/IEC 42001:2023 Control Mapping

### Clause 4: Context of the Organization

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 4.1 Understanding the organization | DePIN federation model documented | `README.md`, `PROPOSAL_V5_EVOLUTION.md` |
| 4.2 Needs and expectations of interested parties | Treaty protocol (multi-stakeholder) | `docs/TREATY_PROTOCOL.md` |
| 4.3 Scope of AI management system | Aurora federation layer (7 networks) | `AURORA_GA_ANNOUNCEMENT.md` |
| 4.4 AI management system | Remembrancer (audit + provenance) | `docs/REMEMBRANCER.md` |

### Clause 5: Leadership

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 5.1 Leadership and commitment | Operator key + covenant foundation | `V3.0_COVENANT_FOUNDATION.md` |
| 5.2 AI policy | vault-law WASM policy (5 constraint types) | `aurora-policy/src/vault_law.rs` |
| 5.3 Organizational roles | Operator runbook (roles + responsibilities) | `DAO_GOVERNANCE_PACK/operator-runbook.md` |

### Clause 6: Planning

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 6.1 Risk and opportunity management | Threat model + mitigation strategies | `THREAT_MODEL.md` |
| 6.2 AI objectives | Treaty fill rate, RTT, provenance coverage | `AURORA_GA_ANNOUNCEMENT.md` (KPIs) |
| 6.3 Planning of changes | Staging → canary → production protocol | `AURORA_STAGING_CANARY_QUICKSTART.md` |

### Clause 7: Support

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 7.1 Resources | K8s deployment specs (CPU/memory) | `ops/k8s/overlays/*/kustomization.yaml` |
| 7.2 Competence | Operator runbook + training materials | `ops/runbooks/AURORA_OPERATIONS.md` |
| 7.3 Awareness | Documentation pack (9 guides) | `v4.5-scaffold/docs/` |
| 7.4 Communication | Slack + PagerDuty integration | `AURORA_STAGING_CANARY_QUICKSTART.md` |
| 7.5 Documented information | Git repo + GPG-signed releases | `.git/`, `dist/*.asc` |

### Clause 8: Operation

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 8.1 Operational planning | Rollout plan (4-week phased deployment) | `AURORA_GA_ANNOUNCEMENT.md` |
| 8.2 AI system lifecycle | Spawn Elite (infrastructure forge) | `spawn.sh`, `generators/` |
| 8.3 Data quality | Schema validation (JSON Schema v4) | `aurora-schemas/order.schema.json` |
| 8.4 AI system impact assessment | Threat model (attack vectors documented) | `THREAT_MODEL.md` |

### Clause 9: Performance Evaluation

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 9.1 Monitoring, measurement, analysis | Prometheus + Grafana dashboards | `aurora-federation/src/metrics.rs` |
| 9.2 Internal audit | Merkle audit log (tamper-evident) | `ops/bin/remembrancer verify-audit` |
| 9.3 Management review | 7-day SLO report (governance cycle) | `AURORA_GA_ANNOUNCEMENT.md` (Week 4) |

### Clause 10: Improvement

| Requirement | Aurora Implementation | Evidence |
|-------------|----------------------|----------|
| 10.1 Nonconformity and corrective action | Incident procedures (runbook) | `ops/runbooks/AURORA_OPERATIONS.md` |
| 10.2 Continual improvement | Optimization cycle (Week 4: credit pricing) | `AURORA_GA_ANNOUNCEMENT.md` |

---

## Cryptographic Evidence Chain

Aurora's **four-step verification** provides **non-repudiable proof** for audit:

```
1. SHA256 hash       → Content integrity (FIPS 180-4)
2. GPG signature     → Authenticity (RFC 4880, ED25519)
3. RFC 3161 token    → Existence proof (dual-TSA)
4. Merkle audit      → Tamper detection (ops/data/remembrancer.db)
```

**Audit Command:**

```bash
./ops/bin/remembrancer verify-full aurora-20251022.tar.gz
# Output: ✅ All four checks passed
```

---

## Traceability Matrix

| Compliance Requirement | Technical Control | Verification Method |
|------------------------|-------------------|---------------------|
| **NIST AI RMF: GOVERN 4.1** (System inventory) | Merkle audit log | `./ops/bin/remembrancer list deployments` |
| **NIST AI RMF: MEASURE 1.1** (Performance metrics) | Prometheus exporters | `curl http://aurora-federation:8080/metrics` |
| **NIST AI RMF: MANAGE 2.1** (Incident documentation) | Receipts + timestamps | `ls ops/receipts/deploy/` |
| **ISO 42001: 8.3** (Data quality) | Schema validation | `make test` (JSON Schema assertions) |
| **ISO 42001: 9.2** (Internal audit) | Merkle integrity check | `./ops/bin/remembrancer verify-audit` |

---

## Attestation

**System:** Aurora GA (v1.0.0)  
**Checksum:** `acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8`  
**Operator Key:** `6E4082C6A410F340`  
**Timestamp Authority:** FreeTSA (public) + [Enterprise TSA]  
**Audit Trail:** `ops/data/remembrancer.db` (Merkle root: [see current root])

**Certification:** This mapping is based on Aurora GA's technical implementation as of October 22, 2025. For independent verification, audit the cryptographic receipts in `ops/receipts/`.

---

## Audit Readiness

### Evidence Packages Available

1. **Source Code Archive** — `aurora-20251022.tar.gz` (GPG-signed)
2. **Cryptographic Receipts** — `ops/receipts/` (Merkle-audited)
3. **Operational Logs** — Prometheus/Grafana exports (7-day retention)
4. **Governance Records** — `docs/adr/` (Architectural Decision Records)
5. **Test Results** — `make smoke-e2e` output (CI artifacts)

### Independent Verification

```bash
# Clone repository
git clone https://github.com/VaultSovereign/vm-spawn
cd vm-spawn

# Verify GPG signature
gpg --verify aurora-20251022.tar.gz.asc aurora-20251022.tar.gz

# Verify checksum
echo "acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8  aurora-20251022.tar.gz" | shasum -a 256 -c

# Verify Merkle audit
./ops/bin/remembrancer verify-audit

# Run compliance checks
make covenant
./ops/bin/health-check
```

---

## Contact for Audit

**Technical POC:** VaultSovereign Operations  
**Compliance Artifacts:** Available in `ops/receipts/` and `docs/adr/`  
**Independent Auditor Access:** Git repository (public), cryptographic receipts (timestamped)

---

**This annex is GPG-signed and RFC 3161 timestamped. Verify with:**

```bash
gpg --verify AURORA_GA_COMPLIANCE_ANNEX.md.asc
openssl ts -verify -in AURORA_GA_COMPLIANCE_ANNEX.md.tsr \
  -data AURORA_GA_COMPLIANCE_ANNEX.md \
  -CAfile ops/certs/cache/public.ca.pem
```

---

**Last Updated:** October 22, 2025  
**Version:** v1.0.0 (Aurora GA)  
**Status:** 🛡️ Compliance-Ready  
**Merkle Root:** `acec72a81172797903efd5ef94efed837a3078e076d754104c9ad994854569a8`
