# VaultMesh — Sovereign Infrastructure Forge
# Makefile for covenant rituals and development workflows

# VaultMesh Covenants
include ops/make.d/covenants.mk
include ops/make.d/federation.mk
include ops/make.d/scheduler.mk
include ops/make.d/docs.mk

.PHONY: help codex-seal codex-verify test health codegen verify-receipts seal verify-finalized anchor-evm anchor-btc anchor-tsa verify-online scheduler governance-propose-cadence covenant-ci docs-check guardian migrate-dry migrate metrics terraform-triage

# Default GPG key (override with: make codex-seal KEY=YOUR_KEY_ID)
KEY ?= 6E4082C6A410F340

help: ## Show this help message
	@echo "🜂 VaultMesh Makefile — Covenant Rituals"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

anchor-evm: ## Anchor latest sealed batch on configured EVM chain
	npm --prefix services/anchors install --no-audit --no-fund
	npm --prefix services/anchors run anchor:evm

anchor-btc: ## Anchor latest sealed batch via Bitcoin OP_RETURN
	npm --prefix services/anchors install --no-audit --no-fund
	npm --prefix services/anchors run anchor:btc

anchor-tsa: ## Anchor latest sealed batch with RFC3161 TSA
	npm --prefix services/anchors install --no-audit --no-fund
	npm --prefix services/anchors run anchor:tsa

verify-online: ## Verify receipt anchors against external trust sources
	@if ls out/receipts/*.json >/dev/null 2>&1; then \
		node services/anchors/simple-verify.js out/receipts/*.json; \
	else \
		echo "No finalized receipts found."; \
	fi


governance-propose-cadence: ## Submit a governance.cadence.set event (example via curl)
	@echo 'Use vmsh or curl to submit a signed envelope with payload matching governance.cadence.set@1.0.0'

covenant-ci: ## CI bundle: covenants, health, audit, docs
	make covenant
	./ops/bin/health-check
	./ops/bin/remembrancer verify-audit
	make docs-check

# ========== Tem Guardian (Repository Hygiene) ==========

guardian: ## Run Tem Guardian (covenant enforcer)
	@echo "🜂 Invoking Tem, Guardian of Remembrance..."
	@python3 .github/scripts/tem_guardian.py

migrate-dry: ## Preview migration operations (Nigredo phase)
	@bash scripts/vaultmesh_migrate.sh --dry-run

migrate: ## Execute migration operations (WARNING: moves files)
	@bash scripts/vaultmesh_migrate.sh --apply

terraform-triage: ## Analyze 3 divergent terraform configs
	@bash scripts/terraform_triage.sh

metrics: ## Show repository hygiene metrics
	@echo "== VaultMesh Hygiene Metrics =="
	@echo "Root .md count: $$(ls -1 *.md 2>/dev/null | wc -l || echo 0)"
	@echo "Root .txt count: $$(ls -1 *.txt 2>/dev/null | wc -l || echo 0)"
	@echo
	@echo "Service structure compliance:"
	@for svc in services/*; do \
		if [ -d "$$svc" ]; then \
			name=$$(basename $$svc); \
			missing=""; \
			[ ! -d "$$svc/src" ] && missing="$$missing src"; \
			[ ! -d "$$svc/tests" ] && missing="$$missing tests"; \
			[ -d "$$svc/test" ] && missing="$$missing [old-test-dir]"; \
			if [ -z "$$missing" ]; then \
				echo "  ✅ $$name"; \
			else \
				echo "  ⚠️  $$name (missing:$$missing)"; \
			fi; \
		fi; \
	done
