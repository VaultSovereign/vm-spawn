#!/usr/bin/env bash
# monitoring.sh - Generate monitoring stack (Prometheus + Grafana + Docker Compose)
# Usage: monitoring.sh

set -euo pipefail

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

