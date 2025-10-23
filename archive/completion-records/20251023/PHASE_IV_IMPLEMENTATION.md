# Phase IV Implementation Summary: Multi-Tenant Namespace Cadence

## Overview

Phase IV completes the sovereign memory architecture by implementing multi-tenant governance with namespace-specific cadence control. This document summarizes the key components and changes.

## Key Components

### 1. Namespace Configuration System

The `vmsh/config/namespaces.yaml` file defines sovereign namespaces with individual configurations:

- Witness quorum requirements (min_required + allowlist)
- Schema version policies (allowed schema versions)
- Cadence settings for fast/strong/cold anchors
- Target chains and confirmation thresholds

### 2. Harbinger Service Enhancement

The Harbinger service has been updated to enforce namespace-specific admission rules:

- Validates witness signatures against namespace allowlists
- Enforces minimum witness quorum per namespace
- Restricts schema versions based on namespace policy
- Maintains backward compatibility with global policies

### 3. Scheduler Service

The new Scheduler service manages per-namespace anchoring cadences:

- Parses cadence expressions (absolute and relative time)
- Tracks last anchoring time per namespace and level
- Implements φ-backoff for anchor failures
- Maintains state between restarts in `out/state/scheduler.json`

### 4. Governance Schema

Added the `governance.cadence.set` schema to support dynamic cadence updates:

- Secured by namespace-specific governance rules
- Supports partial updates to cadence settings
- Includes memo field for audit trail
- Triggers configuration updates when approved

## Implementation Highlights

1. **Zero-Coupling Architecture:**
   - Each namespace operates independently
   - Failures in one namespace don't affect others
   - Clean upgrade path from single to multi-tenant

2. **Cadence Algebra:**
   - Simple time expressions: `89s`, `5m`, `1h`, `1d`
   - Relative expressions: `34*fast`, `7*strong`
   - Supports flexible scheduling patterns

3. **Dynamic Configuration:**
   - Hot-reloadable namespace configuration
   - Service monitors for configuration changes
   - Graceful handling of added/removed namespaces

## Testing and Verification

### Unit Tests

- `services/scheduler/test/parser.test.ts`: Tests cadence expression parsing
- `services/harbinger/test/admission.test.ts`: Tests namespace admission rules
- `services/scheduler/test/backoff.test.ts`: Tests φ-backoff implementation

### Integration Tests

- `make test-phase-iv`: End-to-end testing of multi-namespace flow
- `make verify-governance`: Tests governance proposal execution
- `make verify-namespace-receipts`: Verifies per-namespace receipts

## Usage

### Updating a Namespace Cadence

1. Submit a governance proposal:
   ```bash
   curl -X POST localhost:8080/events \
     -H 'Content-Type: application/json' \
     -d '{
       "vm:version": "1.0",
       "event:type": "governance.cadence.set",
       "schema": "governance.cadence.set@1.0.0",
       "payload": {
         "namespace": "dao:vaultmesh",
         "cadence": {
           "fast": { "target": "eip155:8453", "every": "45s" }
         },
         "memo": "Increase fast cadence speed from 89s to 45s"
       },
       ...
     }'
   ```

2. If required, submit votes (namespace-dependent)

3. Upon approval, the scheduler will apply the new cadence

## Migration Guide

### Migrating from Single-Tenant to Multi-Tenant

1. Set up initial `namespaces.yaml` with default namespace
2. Update harbinger configuration to point to namespaces.yaml
3. Start the scheduler service alongside existing services
4. Verify with `make verify-migration` to ensure all receipts validate

## Future Enhancements

1. **Federation support** for cross-namespace receipt verification
2. **Delayed namespace transitions** for coordinated governance
3. **Namespace templates** for quick provisioning of common patterns
4. **Multi-rail anchoring** within a single cadence level