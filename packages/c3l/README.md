# VaultMesh — C3L (Critical Civilization Communication Layer)

**C3L** integrates **Model Context Protocol (MCP)** and **Message Queues (RabbitMQ/NATS)** to create a distributed communication backbone for spawned services.

## Quick Start

1) **Run RabbitMQ for local dev**

```bash
docker compose -f templates/message-queue/rabbitmq-compose.yml up -d
```

2) **Spawn a service with MCP + MQ**

```bash
./spawn.sh herald --with-mcp --with-mq rabbitmq
```

3) **Run the MCP server (stdio dev)**

```bash
cd services/herald
uv run mcp dev mcp/server.py
```

4) **Run a worker (RabbitMQ)**

```bash
uv run python mq/mq.py
```

## Docs

- `PROPOSAL_MCP_COMMUNICATION_LAYER.md` — full proposal (852 lines).  
- `docs/C3L_ARCHITECTURE.md` — architecture, diagrams.  
- `docs/REMEMBRANCER.md` — Remembrancer MCP integration.

## Notes

- Use CloudEvents envelopes on the bus and propagate `traceparent`.  
- Prefer Streamable HTTP for remote MCP servers; stdio for local dev.