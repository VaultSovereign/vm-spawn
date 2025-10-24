# VaultMesh Scheduler Service (Production Ready – Tests Pending Fix)

Automates cadence-based anchoring per namespace with structured logging, Prometheus metrics,
health endpoints, adaptive φ-backoff, async I/O, and config hot-reload (hash-based).
> **Status:** Code is production-safe, but Jest currently points to `test/` instead of `tests/`.  
> Fix the config before trusting `npm test`, and integrate the Anchors service once its writers are finalized.

## Quickstart
```bash
cd services/scheduler
cp .env.example .env
npm install
npm run dev
```

## Endpoints
- Metrics: `GET /metrics` (Prometheus text format)
- Health:  `GET /health`

## Configuration
- `.env`: see `.env.example`
- `VMSH_ROOT`, `VMSH_NAMESPACES`, `VMSH_STATE`, `VMSH_TICK_MS`, `METRICS_PORT`

## Testing
```bash
# NOTE: Update jest.config.ts (roots -> "tests") before running.
npm test
npm run test:unit
npm run test:integration
```

## Architecture

The scheduler runs a periodic tick loop (default 10s) that:
1. Loads namespace config (YAML) with hash-based caching
2. Validates config with Zod schemas
3. Processes each namespace in parallel with `Promise.allSettled`
4. Checks cadences (fast/strong/cold) and anchors when due
5. Handles failures with adaptive φ-backoff based on error type
6. Emits Prometheus metrics and structured logs
7. Exposes health status via HTTP endpoint

## Metrics

- `vmsh_anchors_attempted_total{namespace,cadence,target}` - Total attempts
- `vmsh_anchors_succeeded_total{namespace,cadence,target}` - Successes
- `vmsh_anchors_failed_total{namespace,cadence,target}` - Failures
- `vmsh_backoff_state{namespace}` - Current backoff level (0-7)
- `vmsh_anchor_duration_seconds{namespace,cadence,target,status}` - Duration histogram

## Health Status

GET `/health` returns:
```json
{
  "status": "healthy|degraded|unhealthy",
  "uptime": 123.45,
  "lastTick": 1729740000000,
  "namespaces": {
    "my-namespace": {
      "lastAnchor": {"fast": 1729739900, "strong": 1729739800},
      "backoff": 0,
      "status": "ok|backing_off|stale"
    }
  }
}
```

## VaultMesh Integration

- **Layer**: 2 (Remembrancer - Cryptographic Memory)
- **Covenant Alignment**: 
  - Integrity (Merkle updates via anchoring)
  - Proof-Chain (TSA/blockchain anchoring)
- **Generated via**: `./spawn.sh scheduler service` (enhanced with monitoring)
- **Uses**: `npm --prefix services/anchors run anchor:*` scripts for anchoring (requires Anchors service configuration)

## Adaptive φ-Backoff

Uses golden ratio (φ ≈ 1.618) for exponential backoff with error-type multipliers:

- **Network errors**: 1.0x (standard)
- **Auth errors**: 2.0x (slower, needs operator intervention)
- **Validation errors**: 0.5x (faster, might be transient)

Formula: `delay = BASE_BACKOFF * φ^k * multiplier`

Capped at MAX_BACKOFF attempts (default 7).

## Troubleshooting

### Scheduler not starting
- Check `.env` configuration
- Verify `vmsh/config/namespaces.yaml` exists and is valid
- Check logs: `LOG_LEVEL=debug npm run dev`

### Anchors failing repeatedly
- Check metrics at `/metrics` for failure patterns
- Review logs for error classification
- Verify target services (EVM, BTC, TSA) are reachable
- Check health status: `curl localhost:9090/health`

### High backoff levels
- Review error messages in structured logs
- For AUTH errors: verify credentials/keys
- For NETWORK errors: check connectivity
- For persistent issues: restart with clean state

## Federation Support (Phase V)

Future enhancement: sync scheduler state with peers via gossip protocol for distributed anchoring coordination.
