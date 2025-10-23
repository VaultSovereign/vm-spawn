# Phase V — Federation (Overview)

The Remembrancer now gossips sealed batches and anchors across trusted peers. Each node re-verifies
foreign anchors with local policies and converges on the strongest attestation. Anti-entropy closes
gaps after partitions. Governance controls peer admission and per-namespace routing.

## Architecture

Phase V implements peer-to-peer federation for VaultMesh's Remembrancer, enabling:
- Cross-node anchor replication with local re-verification
- Deterministic conflict resolution (BTC > EVM > TSA)
- Anti-entropy range sync for partition recovery
- Governance-controlled peer routing per namespace

## Key Components

### Federation Service (`services/federation/`)
- **HTTP Endpoints**: `/federation/announce` and `/federation/request`
- **Gossip Protocol**: Broadcast batch announcements to peers
- **Bundle Serving**: Respond to peer requests with receipt bundles
- **Local Re-verification**: Import anchors only after local policy validation

### Configuration
- `vmsh/config/federation.yaml`: Node identity, listen address, per-namespace peer routing
- `vmsh/config/peers.yaml`: DID allowlist with roles and verification keys

### CLI Tools
- `tools/vmsh-federation.ts`: Status and sync commands

### Documentation
- `FEDERATION_PROTOCOL.md`: Wire protocol, messages, conflict resolution
- `FEDERATION_OPERATIONS.md`: Deployment, incident response, runbooks

## Wire Protocol

### Messages
1. **Announce**: `{ namespace, batchId, batchRoot, anchors[], ts, signer }`
   - Broadcast when a batch is sealed and anchored
   - Peers can request the full bundle

2. **Request**: `{ namespace, fromTs?, toTs?, want?, ts, signer }`
   - Request receipts for a specific namespace/time range
   - Returns a Bundle response

3. **Bundle**: `{ receipts[], anchors[], ts, signer }`
   - Contains requested receipts and their anchors
   - Receiver re-verifies all anchors with local policies

All messages are JCS-canonicalized and signed (DID signatures pending).

## Conflict Resolution

When multiple anchors exist for the same batch:

1. **Finality preference**: `btc:* > eip155:* > rfc3161:*`
2. **Block height**: Higher block number wins (within same chain)
3. **Tie-breaker**: Lexicographic `(chainId, txHash)`

Losing anchors are retained with `superseded_by` references for audit trail.

## Anti-Entropy

Nodes periodically:
1. List local receipt IDs by namespace
2. Request missing ranges from peers
3. Import and re-verify received bundles
4. Update local receipt index

Range requests use `fromTs`/`toTs` or explicit `want` arrays.

## Security Model

### Peer Authentication
- **Allowlist**: `peers.yaml` defines trusted DIDs with roles
- **Roles**: `announce` (can broadcast), `serve` (can respond), `request` (can pull)
- **Verification Keys**: Ed25519 public keys for signature validation

### Local Re-verification
- All imported anchors are verified using local `services/anchors/` verifiers:
  - EVM: Check block confirmation depth
  - BTC: Validate OP_RETURN inclusion
  - TSA: RFC 3161 token verification
- Reject receipts that fail local policy

### Rate Limiting
- Per-namespace request limits (configured in `federation.yaml`)
- Backpressure via HTTP 429 responses

## Integration with Existing Phases

### Phase I-III: Sealing & Anchoring
- Federation triggers after local anchoring completes
- No changes to sealing or single-node anchor logic

### Phase IV: Scheduler Integration
- Scheduler can trigger federation announces after anchoring
- Federation daemon operates independently

## Operational Workflows

### Starting Federation
```bash
make federation
# Starts HTTP server on :8088 (configurable)
# Logs: [federation] node did:vm:node:vm-spawn-a
```

### Checking Status
```bash
npx ts-node tools/vmsh-federation.ts status
# Shows peer connectivity and last sync times
```

### Manual Sync
```bash
npx ts-node tools/vmsh-federation.ts sync --namespace dao:vaultmesh
# Requests bundles from configured peers
```

### Verifying Imported Anchors
```bash
make verify-online
# Re-verifies all anchors (local + federated) against live chains/TSAs
```

## Deployment Checklist

1. ✅ Configure `vmsh/config/federation.yaml` with node DID and listen address
2. ✅ Add peers to `vmsh/config/peers.yaml` with verification keys
3. ✅ Ensure `services/anchors/` verifiers are configured
4. ✅ Start federation daemon: `make federation`
5. ✅ Monitor logs for peer connection status
6. ✅ Test with manual sync: `vmsh-federation.ts sync`
7. ✅ Verify anchors: `make verify-online`

## Covenant Alignment

| Covenant | Alignment |
|----------|-----------|
| **Integrity** | Each node re-verifies all imported anchors; Merkle roots maintained per-node |
| **Reproducibility** | Conflict resolution is deterministic; federation protocol is versioned |
| **Federation** | ✅ This phase implements cross-node federation |
| **Proof-Chain** | All anchors validated against live blockchains/TSAs before acceptance |

## Future Enhancements (Phase V+)

- **DID/JWS Signatures**: Full cryptographic signing of federation messages
- **Automated Anti-Entropy**: Timer-based background sync
- **Quorum Consensus**: Multi-peer agreement before accepting anchors
- **Federation Explorer**: Web UI for peer network visualization
- **Cross-Namespace Routing**: Dynamic peer selection based on namespace policies

## Troubleshooting

### Peer Not Connecting
- Check `peers.yaml` DID matches remote node's `federation.yaml` node_id
- Verify network connectivity: `curl http://peer-url:8088/health`
- Review federation daemon logs for auth errors

### Anchors Rejected
- Run `make verify-online` to see which verifier failed
- Check confirmation thresholds in `vmsh/config/federation.yaml`
- Verify remote anchor is confirmed on-chain

### High Latency
- Increase rate limits in `federation.yaml`
- Add more peers for load distribution
- Check network bandwidth between nodes

## References

- **Protocol**: `docs/FEDERATION_PROTOCOL.md`
- **Operations**: `docs/FEDERATION_OPERATIONS.md`
- **Federation Semantics**: `docs/FEDERATION_SEMANTICS.md`
- **Code**: `services/federation/`
- **Make Targets**: `ops/make.d/federation.mk`

---

**Status**: ✅ Deployed (v4.1-genesis+)  
**Covenant**: ✅ Federation (Citrinitas) Complete  
**Dependencies**: Phases I-IV  
**Next**: Automated anti-entropy, quorum consensus
