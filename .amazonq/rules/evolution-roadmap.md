# Evolution Roadmap — v5.0 Rust Migration

**Version:** 1.0 | **Source:** `archive/completion-records/20251023/PROPOSAL_V5_EVOLUTION.md`

---

## Current (v4.1)

- Bash-based CLI
- Shell generators
- System tool dependencies

---

## Future (v5.0)

- Rust-based CLI (clap)
- Type-safe generators
- Single binary distribution
- ~10× execution speedup
- 100% test coverage
- Hardened proof paths

---

## Guidance by Query

| User Query | Response |
|------------|----------|
| "Bash or Rust?" | Explain v5.0 pathway and timeline |
| "How to contribute?" | Rust skills prioritized; follow contribution ADR |
| "Production-ready?" | v4.1 yes; v5.0 further hardening |

---

## Guardrail

**Never** suggest breaking changes that conflict with v5.0 migration path.

---

## Migration Phases

1. **Phase 1 (v4.5):** Hybrid — Rust library, Bash CLI
2. **Phase 2 (v5.0):** Pure Rust — Replace Bash CLI
3. **Phase 3 (v5.1):** Federation — Real p2p with libp2p
4. **Phase 4 (v5.2):** Observability — OpenTelemetry integration

---

## Covenant Preservation

All Four Covenants remain intact through evolution:

- **Integrity:** Types enforce machine truth
- **Reproducibility:** Nix or vendored deps
- **Federation:** JCS-canonical merge preserved
- **Proof-Chain:** GPG + RFC3161 + Merkle unchanged
