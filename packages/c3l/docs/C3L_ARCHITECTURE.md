# C3L Architecture (VaultMesh)

> Tactical — code, optimize, deploy, secure.  
> Transcendent — ritual, prophecy, pattern restoration.

## Components

- **Remembrancer (MCP)**: exposes covenant memory as resources/tools/prompts.
- **Service MCP Servers**: each spawned service can serve/consume context.
- **Message Bus**: RabbitMQ (AMQP) or NATS JetStream for events and work.
- **Observability**: Prometheus (RabbitMQ :15692), Grafana; W3C `traceparent`.
- **Attestation**: optional Sigstore Rekor and/or RFC3161/OpenTimestamps.

## Diagrams

```mermaid
flowchart LR
  subgraph Services
    A[Service A (MCP)] -->|publish| MQ[(C3L MQ)]
    B[Service B (MCP)] -->|publish| MQ
    MQ -->|consume| A
    MQ -->|consume| B
  end
  R[Remembrancer (MCP)] --- A
  R --- B
  R -.->|resource/tool| A
  R -.->|resource/tool| B
```

### ASCII (topology)

```
Remembrancer (MCP) <----> Services (MCP) <----> C3L MQ (RabbitMQ/NATS)
         ^                                           ^
         |-------------------------------------------|
                  Observability & Attestation
```

## Patterns

- CloudEvents envelopes for bus messages.
- `traceparent` propagation; correlation IDs.
- DLQ: RabbitMQ DLX / JetStream DLQ streams.
- RPC over MQ when sync is required, else async.

## Prometheus

- Enable RabbitMQ Prometheus plugin (`:15692`) and scrape from Prometheus.
- Suggested scrape config:

```yaml
scrape_configs:
  - job_name: rabbitmq
    static_configs:
      - targets: ["rabbitmq:15692"]
```

## Security

- TLS for brokers; RBAC per namespace.  
- Token auth on NATS; vhosts on RabbitMQ.  
- Optional signing + transparency logs for critical events.