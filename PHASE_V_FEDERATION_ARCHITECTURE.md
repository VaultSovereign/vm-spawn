# Phase V: Anchor Federation Architecture

## Overview

Phase V implements cross-Remembrancer consensus and geo-redundant proof systems, creating a network of sovereign memory nodes that can coordinate while maintaining their independence.

## Key Components

### 1. Peer-to-Peer Federation Protocol

#### Federation Network Model

```
┌───────────────────┐     ┌───────────────────┐
│ Remembrancer Node │◀──▶│ Remembrancer Node │
│       Alpha       │     │       Beta        │
└───────────────────┘     └───────────────────┘
         ▲                        ▲
         │                        │
         ▼                        ▼
┌───────────────────┐     ┌───────────────────┐
│ Sovereign Memory  │     │ Sovereign Memory  │
│   Tree Alpha      │     │   Tree Beta       │
└───────────────────┘     └───────────────────┘
```

Each node maintains:
- Complete local memory tree
- Local anchor strategy
- Peer registry with trusted keys
- Federation receipt log

#### Anchor Replication Flow

1. Node A commits batch locally
2. Node A signs anchor receipt
3. Node A broadcasts receipt to federation peers
4. Node B verifies and countersigns receipt
5. Node B broadcasts countersignature
6. When quorum achieved, federation receipt is finalized

### 2. Federation Services

#### Peer Service

The peer service handles node discovery and secure communication between Remembrancer nodes:

```typescript
interface PeerMessage {
  type: 'anchor' | 'countersign' | 'receipt' | 'heartbeat';
  sender: string; // DID of sender
  content: Record<string, any>;
  signature: string;
  timestamp: number;
}
```

#### Federation Registry

Maintains trusted peer list and consensus rules:

```yaml
federation:
  name: "vaultmesh-primary"
  quorum: 2
  peers:
    - did: "did:vm:node:east1"
      endpoint: "https://remembrancer-east1.vaultmesh.io"
      pubkey: "z6Mk..."
    - did: "did:vm:node:west1"
      endpoint: "https://remembrancer-west1.vaultmesh.io" 
      pubkey: "z6Mk..."
  anchor_propagation:
    mode: "collaborative" # or "independent"
    retry_strategy: "geometric-backoff"
```

#### Anchor Propagation

Enables configurable modes:
- **Independent**: Each node anchors separately (N anchors)
- **Collaborative**: Nodes coordinate to minimize anchor costs (1 anchor, N verifiers)
- **Hybrid**: Primary anchors on schedule, secondaries only on threshold failure

### 3. Cross-Namespace Transactions

Secure communication between sovereign memory trees:

```typescript
interface CrossNamespaceMessage {
  source: string; // Source namespace
  target: string; // Target namespace
  action: 'invoke' | 'query' | 'notify';
  payload: {
    operation: string;
    parameters: Record<string, any>;
    proof: MerkleProof; // Inclusion proof from source
  };
}
```

### 4. Public Explorer

Transparency layer showing:
- Federation health
- Per-namespace anchor status
- Witness activity
- Memory tree visualizations

## Security Model

1. **Trust Boundaries**
   - Federation peers have limited permissions (countersign only)
   - Cross-namespace messages validated with Merkle proofs
   - Namespace policies remain sovereign

2. **Federation Consensus Rules**
   - Quorum-based decision making for federation receipts
   - Peer scoring based on reliability and honesty
   - Automatic peer probation for misbehavior

3. **Conflict Resolution**
   - Deterministic resolution for conflicting anchor claims
   - Proof preservation for offline analysis
   - Audit trail for consensus violations

## Implementation Plan

### Stage 1: Peer Protocol (Week 1-2)
- P2P message format and validation
- Federation registry and peer discovery
- Secure message passing between nodes

### Stage 2: Anchor Federation (Week 3-4)
- Collaborative anchoring implementation
- Countersignature mechanism
- Federation receipt structure

### Stage 3: Cross-Namespace Messaging (Week 5-6)
- Cross-namespace message format
- Proof validation system
- Secure message routing

### Stage 4: Explorer & Monitoring (Week 7-8)
- Public explorer UI
- Anchor status dashboard
- Federation health monitoring

## Federation Registry Schema

```json
{
  "$id": "https://vaultmesh.io/schemas/federation.registry.set@1.0.0.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Federation Registry Update",
  "description": "Schema for managing federation peers and consensus rules",
  "type": "object",
  "required": ["federation_id", "registry"],
  "properties": {
    "federation_id": {
      "type": "string",
      "description": "Unique identifier for the federation"
    },
    "registry": {
      "type": "object",
      "properties": {
        "peers": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["did", "endpoint", "pubkey"],
            "properties": {
              "did": { "type": "string" },
              "endpoint": { "type": "string", "format": "uri" },
              "pubkey": { "type": "string" },
              "status": {
                "type": "string",
                "enum": ["active", "probation", "suspended"]
              }
            }
          }
        },
        "quorum": {
          "type": "integer",
          "minimum": 1
        },
        "anchor_strategy": {
          "type": "string",
          "enum": ["collaborative", "independent", "hybrid"]
        }
      }
    },
    "memo": {
      "type": "string"
    }
  }
}
```

## Cross-Namespace Message Schema

```json
{
  "$id": "https://vaultmesh.io/schemas/namespace.message@1.0.0.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Cross-Namespace Message",
  "description": "Schema for messages between sovereign namespaces",
  "type": "object",
  "required": ["source", "target", "action", "payload"],
  "properties": {
    "source": {
      "type": "string",
      "pattern": "^[a-z0-9]+:[a-z0-9]+$"
    },
    "target": {
      "type": "string",
      "pattern": "^[a-z0-9]+:[a-z0-9]+$"
    },
    "action": {
      "type": "string",
      "enum": ["invoke", "query", "notify"]
    },
    "payload": {
      "type": "object",
      "required": ["operation", "parameters", "proof"],
      "properties": {
        "operation": { "type": "string" },
        "parameters": { "type": "object" },
        "proof": {
          "type": "object",
          "description": "Merkle inclusion proof from source namespace",
          "required": ["root", "path", "leaf"],
          "properties": {
            "root": { "type": "string" },
            "path": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "position": { "type": "string", "enum": ["left", "right"] },
                  "hash": { "type": "string" }
                }
              }
            },
            "leaf": { "type": "string" }
          }
        }
      }
    }
  }
}
```

## Federation Receipt Example

```json
{
  "federation_id": "vaultmesh-primary",
  "receipt_type": "anchor_federation",
  "namespace": "dao:vaultmesh",
  "anchor": {
    "batch_root": "sha256:d5c64aee1039e6dd71f5818d456cce2e48e6590b6953c13623af6fa1070decea",
    "target": "eip155:1",
    "tx_hash": "0x1234...",
    "block": 18345201,
    "timestamp": 1698042601
  },
  "signatures": [
    {
      "node": "did:vm:node:east1",
      "sig": "z58iPCUFF...",
      "role": "anchor",
      "timestamp": 1698042610
    },
    {
      "node": "did:vm:node:west1",
      "sig": "z58Jd6AZz...",
      "role": "witness",
      "timestamp": 1698042615
    },
    {
      "node": "did:vm:node:central1",
      "sig": "z58JHG7V...",
      "role": "witness",
      "timestamp": 1698042619
    }
  ],
  "quorum_met": true,
  "finalized_at": 1698042620
}
```

## Command-line Interface

```bash
# Start federation peer service
npm run federation-peer

# Register with federation
./ops/bin/remembrancer federation join --federation vaultmesh-primary --node did:vm:node:east1

# View federation status
./ops/bin/remembrancer federation status

# Force anchor propagation
./ops/bin/remembrancer federation propagate-anchor namespace:dao:vaultmesh

# Cross-namespace message
./ops/bin/remembrancer namespace message \
  --from dao:vaultmesh \
  --to fin:clearing \
  --action notify \
  --operation status.update \
  --payload '{"status":"completed"}'
```

## Roadmap Milestones

1. **P2P Framework** - Secure peer communication established
2. **Federation Consensus** - Multi-node anchoring with quorum
3. **Cross-namespace Messaging** - Proof-verified communication between namespaces
4. **Public Explorer** - Federation health dashboard with anchor status
5. **DAO/Treasury Integration** - Governance for federation management

---

**Phase V Status:** 🚧 Design & Planning Phase  
**Target Completion:** 2025-12-15  
**Dependencies:** Phase IV multi-tenant system