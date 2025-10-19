#!/usr/bin/env bash
# add-elite-features.sh - Adds elite features to spawned repo
# Run this AFTER the base spawn to add K8s, CI/CD, monitoring

set -euo pipefail

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

echo "🔥 Adding ELITE features to $(basename "$PWD")..."

# ==================================================================
# CI/CD - GitHub Actions
# ==================================================================
mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'CI'
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: make test
      
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          
  docker:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: docker/build-push-action@v4
        with:
          context: .
          push: false
          tags: ${{ github.repository }}:latest
CI

echo "✅ GitHub Actions CI/CD"

# ==================================================================
# Kubernetes - Base manifests
# ==================================================================
mkdir -p deployments/kubernetes/base
cat > deployments/kubernetes/base/deployment.yaml << 'K8S'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: APP_NAME
  template:
    metadata:
      labels:
        app: APP_NAME
    spec:
      containers:
      - name: APP_NAME
        image: APP_NAME:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: APP_NAME
spec:
  selector:
    app: APP_NAME
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: APP_NAME
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: APP_NAME
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
K8S

# Replace APP_NAME with actual name
APP_NAME=$(basename "$PWD")
sed -i.bak "s/APP_NAME/$APP_NAME/g" deployments/kubernetes/base/deployment.yaml

echo "✅ Kubernetes manifests"

# ==================================================================
# Docker Compose - Full stack
# ==================================================================
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ENV=development
    volumes:
      - .:/app
    depends_on:
      - prometheus
      - grafana
      
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - ./monitoring/grafana:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      
volumes:
  prometheus_data:
  grafana_data:
COMPOSE

echo "✅ Docker Compose with monitoring"

# ==================================================================
# Monitoring configs
# ==================================================================
mkdir -p monitoring/prometheus monitoring/grafana
cat > monitoring/prometheus/prometheus.yml << 'PROM'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app:8000']
PROM

echo "✅ Prometheus config"

# ==================================================================
# Enhanced Dockerfile (multi-stage)
# ==================================================================
cat > Dockerfile.elite << 'DOCKER'
# Multi-stage production Dockerfile
FROM python:3.11-slim as builder

WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

FROM python:3.11-slim

# Security: non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Install from wheels
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

# Copy app
COPY --chown=appuser:appuser . .

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s \
  CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

echo "✅ Elite Dockerfile"

# ==================================================================
# Summary
# ==================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🎉 ELITE FEATURES ADDED!"
echo "════════════════════════════════════════════════"
echo ""
echo "Added:"
echo "  ✅ .github/workflows/ci.yml          - CI/CD pipeline"
echo "  ✅ deployments/kubernetes/           - K8s manifests + HPA"
echo "  ✅ docker-compose.yml                - Full dev stack"
echo "  ✅ monitoring/prometheus/            - Metrics config"
echo "  ✅ Dockerfile.elite                  - Production container"
echo ""
echo "Try:"
echo "  docker-compose up -d                 - Start full stack"
echo "  kubectl apply -f deployments/kubernetes/base/  - Deploy to K8s"
echo "  docker build -f Dockerfile.elite -t $APP_NAME:elite ."
echo ""
