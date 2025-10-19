# Remembrancer — MCP Integration

The Remembrancer is exposed as an **MCP server** that provides:
- **Resources**: `memory://{ns}/{id}`, `adr://{year}/ADR-{num}`
- **Tools**: `search_memories`, `record_decision`, `index_artifact`
- **Prompts**: `decision_summary`, `risk_register`

## Running (dev, stdio)

```bash
uv run mcp dev mcp/server.py
```

## Security

- Per-namespace RBAC, token-scoped.  
- Optional event signing + transparency logs for critical entries.

## Federation

- Services may query Remembrancer across nodes via HTTP transport.  
- Cache projections locally and reconcile via domain events.