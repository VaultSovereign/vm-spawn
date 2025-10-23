.PHONY: build test run clean docker docker-push

# Variables
SERVICE_NAME := psi-field
VERSION := v1.0.0
DOCKER_IMAGE := vaultmesh/$(SERVICE_NAME):$(VERSION)

# Build
build:
	pip install -r requirements.txt

# Run tests
test:
	pytest tests/ -v

# Run locally
run:
	uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Clean
clean:
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf .coverage

# Docker
docker:
	docker build -t $(DOCKER_IMAGE) .

# Push Docker image
docker-push: docker
	docker push $(DOCKER_IMAGE)

# Setup for development
setup-dev:
	pip install -r requirements.txt
	pip install pytest pytest-cov black isort flake8

# Format code
format:
	black src tests
	isort src tests

# Lint code
lint:
	flake8 src tests