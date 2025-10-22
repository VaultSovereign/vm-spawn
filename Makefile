# VaultMesh — Sovereign Infrastructure Forge
# Makefile for covenant rituals and development workflows

# VaultMesh Covenants
include ops/make.d/covenants.mk

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

.PHONY: treaty-verify policy-build order-send metrics-run k8s-apply

treaty-verify: ## Canonicalize the Aurora treaty JSON
	jq -cS . templates/aurora-treaty-akash.json > /tmp/treaty.canon.json
	@echo "Treaty canonicalized → /tmp/treaty.canon.json"

policy-build: ## Build the vault-law Akash policy to WASM
	rustup target add wasm32-unknown-unknown || true
	( cd v4.5-scaffold && cargo build --release --target wasm32-unknown-unknown -p vault-law-akash-policy )
	mkdir -p policy/wasm
	cp v4.5-scaffold/target/wasm32-unknown-unknown/release/vault_law_akash_policy.wasm policy/wasm/vault-law-akash-policy.wasm

order-send: ## Submit an Aurora treaty order to the configured bridge
	@AURORA_BRIDGE_URL?=http://localhost:8080; \
	chmod +x scripts/aurora-order-submit.sh; \
	bash scripts/aurora-order-submit.sh tmp/order.json

metrics-run: ## Run the Aurora metrics exporter on port 9109
	python3 scripts/aurora-metrics-exporter.py

k8s-apply: ## Apply the Aurora treaty GPU job manifest
	kubectl -n aurora-akash apply -f ops/k8s/vm-spawn-llm-infer.yaml

.PHONY: sim-run sim-metrics-run smoke-e2e

sim-run: ## Run the multi-provider routing war-game simulator (SEED=42 STEPS=120)
	@SEED=$${SEED:-42}; \
	STEPS=$${STEPS:-120}; \
	SEED=$$SEED STEPS=$$STEPS python3 sim/multi-provider-routing-simulator/sim/sim.py

sim-metrics-run: ## Run the simulator metrics exporter on port 9110
	python3 scripts/sim-metrics-exporter.py

smoke-e2e: ## Run end-to-end smoke test (keys + mock + sim + metrics)
	@bash scripts/smoke-e2e.sh

.PHONY: staging-apply staging-destroy staging-status staging-portfwd-bridge staging-portfwd-metrics staging-logs staging-create-secret

staging-apply: ## Deploy Aurora to staging (Kustomize overlay)
	kubectl apply -k ops/k8s/overlays/staging

staging-destroy: ## Destroy staging deployment
	kubectl delete -k ops/k8s/overlays/staging

staging-status: ## Check staging deployment status
	@echo "=== Staging Status ==="
	kubectl -n aurora-staging get all,netpol,pdb,quota,limitrange
	@echo ""
	@echo "=== Pod Status ==="
	kubectl -n aurora-staging get pods -o wide

staging-portfwd-bridge: ## Port-forward staging bridge to localhost:8080
	kubectl -n aurora-staging port-forward svc/aurora-bridge 8080:8080

staging-portfwd-metrics: ## Port-forward staging metrics to localhost:9109
	kubectl -n aurora-staging port-forward svc/aurora-metrics-exporter 9109:9109

staging-logs: ## Tail logs from staging pods
	@echo "=== Aurora Bridge Logs ==="
	kubectl -n aurora-staging logs -l app=aurora-bridge --tail=50 -f

staging-create-secret: ## Create aurora-pubkey secret (requires secrets/vm_httpsig.pub)
	@if [ ! -f secrets/vm_httpsig.pub ]; then \
		echo "Error: secrets/vm_httpsig.pub not found"; \
		echo "Run: make smoke-e2e (generates keys automatically)"; \
		exit 1; \
	fi
	kubectl -n aurora-staging create secret generic aurora-pubkey \
		--from-file=vm_httpsig.pub=secrets/vm_httpsig.pub \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ Secret created"

.PHONY: dist
dist: policy-build ## Build signed Aurora GA artifact
	@echo "[dist] Creating release bundle…"
	mkdir -p dist
	tar -czf dist/aurora-$(shell date +%Y%m%d).tar.gz \
		policy/wasm/*.wasm \
		schemas/*.json \
		scripts/*.py \
		scripts/*.sh \
		ops/grafana/*.json \
		ops/grafana/*.yaml \
		ops/k8s/vm-spawn-llm-infer.yaml \
		ops/k8s/overlays/staging/* \
		docs/*.md
	@echo "[dist] Signing artifact with covenant key"
	GPG_TTY=$$(tty) gpg --batch --yes --pinentry-mode loopback --detach-sign --armor --local-user $(KEY) dist/aurora-$(shell date +%Y%m%d).tar.gz
	@echo "[dist] Done → dist/aurora-$(shell date +%Y%m%d).tar.gz (.asc)"
