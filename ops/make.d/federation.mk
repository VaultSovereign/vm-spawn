federation: ## Run federation daemon
	npm --prefix services/federation install --no-audit --no-fund
	npm --prefix services/federation run dev

federation-status: ## Show peerbook & namespace routing
	npx ts-node tools/vmsh-federation.ts status

federation-sync: ## Force sync for a namespace
	npx ts-node tools/vmsh-federation.ts sync dao:vaultmesh
