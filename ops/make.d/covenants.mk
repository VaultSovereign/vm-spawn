EPOCH := $(shell git log -1 --pretty=%ct)
GIT_SHA := $(shell git rev-parse --short HEAD)

.PHONY: repro reprodiff sbom covenant
repro:
	@echo "SOURCE_DATE_EPOCH=$(EPOCH)"
	DOCKER_BUILDKIT=1 docker build \
	  --build-arg SOURCE_DATE_EPOCH=$(EPOCH) \
	  --file Dockerfile.elite \
	  --tag vm/repro:$(GIT_SHA) .
	@mkdir -p ops/artifacts ops/receipts/build
	docker image inspect vm/repro:$(GIT_SHA) --format '{{.Id}}' > ops/artifacts/repro.id

reprodiff:
	@diff -u ops/artifacts/repro.id ops/receipts/build/repro.id || (echo "❌ Repro mismatch"; exit 1)
	@echo "✅ Repro OK"

sbom:
	@which syft >/dev/null 2>&1 && syft . -o json > ops/artifacts/sbom.json || echo "⚠️  syft not installed"

covenant:
	@./ops/bin/covenant

