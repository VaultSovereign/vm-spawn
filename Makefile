# VaultMesh — Sovereign Infrastructure Forge
# Makefile for covenant rituals and development workflows

.PHONY: help codex-seal codex-verify test health

# Default GPG key (override with: make codex-seal KEY=YOUR_KEY_ID)
KEY ?= 6E4082C6A410F340

help: ## Show this help message
	@echo "🜂 VaultMesh Makefile — Covenant Rituals"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

codex-seal: ## Cryptographically seal the Sovereign Lore Codex (GPG + RFC3161)
	@echo "🜂 Sealing Sovereign Lore Codex V1..."
	@echo ""
	@echo "1/6 Signing codex with GPG..."
	./ops/bin/remembrancer sign SOVEREIGN_LORE_CODEX_V1.md --key $(KEY)
	@echo ""
	@echo "2/6 Timestamping codex with RFC3161..."
	./ops/bin/remembrancer timestamp SOVEREIGN_LORE_CODEX_V1.md
	@echo ""
	@echo "3/6 Signing inscription with GPG..."
	gpg --armor --detach-sign -u $(KEY) first_seal_inscription.asc
	@echo ""
	@echo "4/6 Timestamping inscription with RFC3161..."
	./ops/bin/remembrancer timestamp first_seal_inscription.asc
	@echo ""
	@echo "5/6 Verifying full chains..."
	./ops/bin/remembrancer verify-full SOVEREIGN_LORE_CODEX_V1.md
	./ops/bin/remembrancer verify-full first_seal_inscription.asc
	@echo ""
	@echo "6/6 Exporting portable proofs..."
	./ops/bin/remembrancer export-proof SOVEREIGN_LORE_CODEX_V1.md
	./ops/bin/remembrancer export-proof first_seal_inscription.asc
	@echo ""
	@echo "✅ Codex sealed! Proofs exported to .proof.tgz bundles."
	@echo "🜂 Next: git add *.asc *.tsr *.proof.tgz && git commit -m '🜂 Seal Codex V1'"

codex-verify: ## Verify the Codex cryptographic chain (GPG + RFC3161 + Merkle)
	@echo "🜂 Verifying Sovereign Lore Codex V1..."
	@echo ""
	@echo "1/3 Verifying codex..."
	./ops/bin/remembrancer verify-full SOVEREIGN_LORE_CODEX_V1.md
	@echo ""
	@echo "2/3 Verifying inscription..."
	./ops/bin/remembrancer verify-full first_seal_inscription.asc
	@echo ""
	@echo "3/3 Verifying Merkle audit trail..."
	./ops/bin/remembrancer verify-audit
	@echo ""
	@echo "✅ All verifications passed!"

health: ## Run system health check
	@./ops/bin/health-check

test: ## Run smoke tests
	@./SMOKE_TEST.sh

