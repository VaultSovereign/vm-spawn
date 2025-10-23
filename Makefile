# VaultMesh — Sovereign Infrastructure Forge
# Makefile for covenant rituals and development workflows

# VaultMesh Covenants
include ops/make.d/covenants.mk
include ops/make.d/federation.mk
include ops/make.d/scheduler.mk

.PHONY: help codex-seal codex-verify test health codegen verify-receipts seal verify-finalized anchor-evm anchor-btc anchor-tsa verify-online scheduler governance-propose-cadence

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
