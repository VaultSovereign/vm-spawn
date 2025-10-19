# C3L Operations Runbook

**Purpose:** Quick reference for C3L (MCP + Message Queue) operations  
**Version:** v1.0  
**Date:** 2025-10-19

---

## Quick Start

### Start Local Message Queue (Development)

```bash
# Start RabbitMQ with management UI + Prometheus
docker compose -f templates/message-queue/rabbitmq-compose.yml up -d

# Verify
docker ps | grep rabbitmq
curl -s http://localhost:15672  # Management UI (guest/guest)
curl -s http://localhost:15692/metrics | grep rabbitmq  # Prometheus metrics
```

### Stop Message Queue

```bash
docker compose -f templates/message-queue/rabbitmq-compose.yml down
```

---

## Spawn Matrix (Development)

### Individual Features

```bash
# MCP only
./spawn.sh herald service --with-mcp
test -f services/herald/mcp/server.py && echo "✅ MCP scaffold created"

# RabbitMQ only
./spawn.sh runner service --with-mq rabbitmq
test -f services/runner/mq/mq.py && echo "✅ RabbitMQ scaffold created"

# NATS only
./spawn.sh courier service --with-mq nats
test -f services/courier/mq/mq.py && echo "✅ NATS scaffold created"

# Full C3L stack
./spawn.sh federation service --with-mcp --with-mq rabbitmq
test -f services/federation/mcp/server.py && \
test -f services/federation/mq/mq.py && \
echo "✅ Full C3L stack created"
```

---

## Sanity Assertions

### Pre-flight Checks

```bash
# Verify generators are executable
test -x generators/mcp-server.sh && echo "✅ mcp-server.sh executable"
test -x generators/message-queue.sh && echo "✅ message-queue.sh executable"

# Verify templates exist
test -f templates/mcp/server-template.py && echo "✅ MCP template present"
test -f templates/message-queue/rabbitmq-compose.yml && echo "✅ RabbitMQ template present"

# Verify proposal integrity
L=$(awk 'END{print NR}' PROPOSAL_MCP_COMMUNICATION_LAYER.md)
test $L -ge 851 && test $L -le 852 && echo "✅ Proposal length: $L lines (valid)"
```

### Post-spawn Checks

```bash
# Verify MCP scaffold
SERVICE="herald"
test -f services/$SERVICE/mcp/server.py && echo "✅ MCP server.py exists"
grep -q "FastMCP" services/$SERVICE/mcp/server.py && echo "✅ Uses FastMCP"

# Verify MQ scaffold (RabbitMQ)
SERVICE="runner"
test -f services/$SERVICE/mq/mq.py && echo "✅ MQ mq.py exists"
grep -q "aio_pika" services/$SERVICE/mq/mq.py && echo "✅ Uses aio-pika"

# Verify MQ scaffold (NATS)
SERVICE="courier"
test -f services/$SERVICE/mq/mq.py && echo "✅ MQ mq.py exists"
grep -q "nats" services/$SERVICE/mq/mq.py && echo "✅ Uses nats-py"
```

---

## Running C3L Services

### MCP Server (stdio for development)

```bash
cd services/herald
uv run mcp dev mcp/server.py

# Or with logging
uv run mcp dev mcp/server.py 2>&1 | tee mcp-server.log
```

### MCP Server (HTTP for production)

```bash
cd services/herald
# Modify server.py to enable HTTP transport
uv run python mcp/server.py --http --port 8080
```

### Message Queue Worker (RabbitMQ)

```bash
cd services/runner
uv run python mq/mq.py

# With environment variables
RABBITMQ_URL=amqp://guest:guest@localhost/ \
uv run python mq/mq.py
```

### Message Queue Worker (NATS)

```bash
cd services/courier
uv run python mq/mq.py

# With environment variables
NATS_URL=nats://localhost:4222 \
uv run python mq/mq.py
```

---

## Prometheus Integration

### RabbitMQ Metrics

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: rabbitmq
    static_configs:
      - targets: ["localhost:15692"]
    scrape_interval: 15s
```

### Key Metrics to Monitor

```promql
# Message rate
rate(rabbitmq_global_messages_delivered_total[5m])

# Queue depth
rabbitmq_queue_messages

# Consumer count
rabbitmq_queue_consumers

# DLX rate (dead letters)
rate(rabbitmq_queue_messages_dead_letter_total[5m])

# Connection count
rabbitmq_connections
```

### Grafana Dashboard

Import dashboard ID: `10991` (RabbitMQ overview)  
Or use: `templates/message-queue/grafana-dashboard.json` (if available)

---

## Troubleshooting

### MCP Server Won't Start

```bash
# Check dependencies
uv run pip list | grep mcp

# Verify template syntax
python -m py_compile services/herald/mcp/server.py

# Check logs
uv run mcp dev mcp/server.py 2>&1 | grep -i error
```

### RabbitMQ Connection Issues

```bash
# Check container status
docker ps | grep rabbitmq

# Check logs
docker logs c3l-rabbitmq

# Verify port accessibility
nc -zv localhost 5672   # AMQP
nc -zv localhost 15672  # Management
nc -zv localhost 15692  # Prometheus

# Test connection
python -c "import aio_pika, asyncio; asyncio.run(aio_pika.connect('amqp://guest:guest@localhost/'))"
```

### NATS Connection Issues

```bash
# Install NATS server (if not running)
docker run -d --name nats -p 4222:4222 nats:latest

# Test connection
python -c "import nats, asyncio; asyncio.run(nats.connect('nats://localhost:4222'))"
```

### Generator Failures

```bash
# Check executable permissions
ls -l generators/mcp-server.sh generators/message-queue.sh

# Run generator manually
bash -x generators/mcp-server.sh test-service --dir /tmp/test

# Check template existence
test -f templates/mcp/server-template.py || echo "❌ Template missing"
```

---

## Rollback Procedures

### Disable C3L (Temporary)

```bash
# Simply don't use C3L flags
./spawn.sh my-service service
# Baseline behavior unchanged
```

### Revert spawn.sh (If Needed)

```bash
# Checkout previous version
git checkout HEAD~1 spawn.sh

# Or revert commit
git revert <commit-hash>
```

### Remove C3L Scaffolds from Service

```bash
# Remove MCP
rm -rf services/my-service/mcp/

# Remove MQ
rm -rf services/my-service/mq/

# Service continues to work without C3L
```

---

## DLQ Monitoring (RabbitMQ)

### Check Dead Letter Exchange

```bash
# Via rabbitmqctl
docker exec c3l-rabbitmq rabbitmqctl list_exchanges

# Via API
curl -u guest:guest http://localhost:15672/api/exchanges/%2F/c3l.dlx
```

### View Dead Lettered Messages

```bash
# List queues bound to DLX
docker exec c3l-rabbitmq rabbitmqctl list_queues name messages

# Inspect specific DLQ
curl -u guest:guest http://localhost:15672/api/queues/%2F/<queue-name>
```

### Replay Dead Letters

```python
# Example replay script
import aio_pika
import asyncio

async def replay_dlq():
    conn = await aio_pika.connect("amqp://guest:guest@localhost/")
    async with conn:
        channel = await conn.channel()
        dlq = await channel.get_queue("my-service.dlq")
        
        async for message in dlq.iterator():
            # Re-publish to original exchange
            await channel.default_exchange.publish(
                aio_pika.Message(body=message.body),
                routing_key="my-service.events"
            )
            await message.ack()

asyncio.run(replay_dlq())
```

---

## Security Hardening

### RabbitMQ Production Config

```yaml
# templates/message-queue/rabbitmq-compose.yml
environment:
  RABBITMQ_DEFAULT_USER: "${RABBITMQ_USER:-admin}"
  RABBITMQ_DEFAULT_PASS: "${RABBITMQ_PASS:-changeme}"
  
# Use .env file
RABBITMQ_USER=production-user
RABBITMQ_PASS=<strong-password>
```

### MCP Token-Based Auth

```python
# In server.py
from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer

security = HTTPBearer()

@app.get("/mcp/resources")
async def resources(token: str = Security(security)):
    if token.credentials != EXPECTED_TOKEN:
        raise HTTPException(status_code=401)
    # ... serve resources
```

### TLS for RabbitMQ

```yaml
# Add to docker-compose.yml
volumes:
  - ./certs:/etc/rabbitmq/certs
environment:
  - RABBITMQ_SSL_CERTFILE=/etc/rabbitmq/certs/server.pem
  - RABBITMQ_SSL_KEYFILE=/etc/rabbitmq/certs/server-key.pem
  - RABBITMQ_SSL_CACERTFILE=/etc/rabbitmq/certs/ca.pem
```

---

## Pre-commit Hooks

### Setup shellcheck + normalizer

```bash
# .git/hooks/pre-commit
#!/bin/bash
set -e

echo "Running shellcheck..."
shellcheck -S warning spawn.sh generators/*.sh

echo "Checking line endings..."
dos2unix --info spawn.sh generators/*.sh | grep -q DOS && {
  echo "❌ DOS line endings detected"
  exit 1
}

echo "✅ Pre-commit checks passed"
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## CI/CD Integration

### GitHub Actions (Already Added)

See `.github/workflows/c3l-guard.yml`

### Additional CI Steps

```yaml
- name: Test MCP server startup
  run: |
    ./spawn.sh ci-mcp service --with-mcp
    cd services/ci-mcp
    timeout 5 uv run python mcp/server.py --test || exit 0

- name: Test MQ connection
  run: |
    docker compose -f templates/message-queue/rabbitmq-compose.yml up -d
    sleep 10  # Wait for RabbitMQ
    ./spawn.sh ci-mq service --with-mq rabbitmq
    cd services/ci-mq
    timeout 5 uv run python mq/mq.py --test
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Start RabbitMQ | `docker compose -f templates/message-queue/rabbitmq-compose.yml up -d` |
| Spawn with MCP | `./spawn.sh <name> service --with-mcp` |
| Spawn with RabbitMQ | `./spawn.sh <name> service --with-mq rabbitmq` |
| Spawn with NATS | `./spawn.sh <name> service --with-mq nats` |
| Run MCP server | `cd services/<name> && uv run mcp dev mcp/server.py` |
| Run MQ worker | `cd services/<name> && uv run python mq/mq.py` |
| Check generators | `test -x generators/*.sh` |
| Verify proposal | `wc -l PROPOSAL_MCP_COMMUNICATION_LAYER.md` |
| RabbitMQ UI | `http://localhost:15672` (guest/guest) |
| Prometheus metrics | `http://localhost:15692/metrics` |

---

**Runbook Status:** ✅ Production Ready  
**Last Updated:** 2025-10-19  
**Maintained By:** VaultMesh Operations

🜂 **The bus hums; the Remembrancer listens.** ⚔️

