DOCS_SCAN_PATTERN=docs/(gke-(cluster|gpu|keda|vaultmesh)\.ya?ml|gcp-confidential-vm(\.tf|\.json|\.md)|gcp-confidential-vm-proof-schema\.json)

.PHONY: docs-check
docs-check: ## Validate docs integrity (AGENTS.md + path references)
	@echo "🔎 Running docs-guardian..."
	@./ops/bin/docs-guardian
	@echo "🔎 Scanning for outdated doc paths..."
	@# Fail if old flat docs paths are referenced instead of the new confidential dirs
	@rg -n --pcre2 "\\bdocs/gke-(cluster|gpu|keda|vaultmesh)\\.ya?ml\\b|\\bdocs/gcp-confidential-vm\\.tf\\b|\\bdocs/gcp-confidential-vm-proof-schema\\.json\\b" -S || true
	@out=$$(rg -n --pcre2 "\\bdocs/gke-(cluster|gpu|keda|vaultmesh)\\.ya?ml\\b|\\bdocs/gcp-confidential-vm\\.tf\\b|\\bdocs/gcp-confidential-vm-proof-schema\\.json\\b" -S | wc -l); \
	 if [ "$$out" -gt 0 ]; then \
	   echo "❌ Found outdated doc path references. Use docs/gke/confidential/* and docs/gcp/confidential/*"; \
	   exit 1; \
	 else \
	   echo "✅ Docs references OK"; \
	 fi

