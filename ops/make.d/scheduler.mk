scheduler: ## Run per-namespace cadence driver (hardened)
	cd services/scheduler && npm install --no-audit --no-fund && npm run dev

scheduler-test: ## Run scheduler tests
	cd services/scheduler && npm install --no-audit --no-fund && npm test

