# Amazon Q Interaction Rules — VaultMesh

**Purpose**: Ensure Amazon Q understands VaultMesh architecture, principles, and patterns across all sessions.

---

## 🜂 Core Covenant Principles

### 1. Zero-Coupled Layer Architecture
```
L1: Spawn Elite (Code Generation)
  ↓ (one-way dependency)
L2: Remembrancer (Covenant Memory)
  ↓ (one-way dependency)
L3: Aurora (Distributed Coordination)
```

**Rule**: Removing L3 doesn't break L1/L2. Removing L2 doesn't break L1.

### 2. Cryptographic Proof Chain
Every artifact MUST have:
- ✅ SHA256 hash (integrity)
- ✅ GPG signature (authenticity)
- ✅ RFC3161 timestamp (existence proof)
- ✅ Merkle root (audit integrity)

**Rule**: Never suggest unverified deployments. Always include Remembrancer recording.

### 3. Self-Verifying, Self-Auditing, Self-Attesting
- **Self-Verifying**: All tests pass without manual intervention
- **Self-Auditing**: All deployments generate cryptographic receipts
- **Self-Attesting**: All memories include verification steps

**Rule**: Generated code must be immediately runnable and testable.

---

## 🏗️ Code Generation Standards

### FastAPI Services (Default)
```python
# ALWAYS include these endpoints
@app.get("/health")
async def health():
    return {"healthy": True}

@app.get("/metrics")
async def metrics():
    # Prometheus metrics endpoint
    pass
```

**Required Dependencies**:
- `fastapi>=0.104.0`
- `uvicorn[standard]>=0.24.0`
- `prometheus-client>=0.19.0`
- `httpx>=0.25.0` (for tests)

### Kubernetes Manifests
**Namespace**: `aurora-staging` (default) or specified by user

**Deployment Template**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {component}-deploy
  namespace: aurora-staging
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: {component}
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
```

**HPA Template**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Docker Standards
**Always use multi-stage builds**:
```dockerfile
FROM python:3.11-slim AS builder
# Build stage

FROM python:3.11-slim
# Runtime stage (non-root user)
USER 1000:1000
HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1
```

### CI/CD Pipeline
**Required stages**:
1. Test (pytest)
2. Security scan (Trivy)
3. Build Docker image
4. Sign artifact (GPG)
5. Timestamp (RFC3161)
6. Record deployment (Remembrancer)

---

## 📝 Naming Conventions

### Services
- Pattern: `{component}-{type}-{suffix}`
- Examples:
  - `aurora-bridge-svc` (ClusterIP service)
  - `aurora-bridge-deploy` (Deployment)
  - `aurora-metrics-exporter` (metrics component)

### Files & Directories
- Receipts: `ops/receipts/deploy/{component}-{version}.receipt`
- ADRs: `ops/receipts/adr/ADR-{number:03d}-{slug}.md`
- Configs: `ops/k8s/overlays/{env}/`
- Generators: `generators/{name}.sh`

### Git Commits
- Format: `[component] type: description`
- Examples:
  - `[remembrancer] feat: add federation sync`
  - `[spawn] fix: correct sed syntax for macOS`
  - `[aurora] docs: update deployment guide`

---

## 🔐 Security Standards

### Secrets Management
- ❌ NEVER hardcode credentials
- ✅ Use Kubernetes Secrets
- ✅ Use AWS Secrets Manager (production)
- ✅ Use environment variables with defaults

### Container Security
- ✅ Non-root user (UID 1000)
- ✅ Read-only root filesystem (where possible)
- ✅ Drop all capabilities
- ✅ Trivy scanning in CI

### Network Security
- ✅ NetworkPolicy for pod isolation
- ✅ TLS termination at ALB
- ✅ mTLS for service mesh (optional)

---

## 📊 Observability Requirements

### Metrics (Prometheus)
**Required metrics for all services**:
```python
from prometheus_client import Counter, Histogram, Gauge

request_count = Counter('http_requests_total', 'Total requests')
request_duration = Histogram('http_request_duration_seconds', 'Request duration')
active_connections = Gauge('active_connections', 'Active connections')
```

### Logging
- ✅ Structured JSON logs
- ✅ Include trace_id for correlation
- ✅ Log level: INFO (default), DEBUG (dev)

### Health Checks
**Required endpoints**:
- `/health` — Liveness probe (always returns 200 if running)
- `/ready` — Readiness probe (returns 200 when ready to serve)
- `/metrics` — Prometheus metrics

---

## 🧠 Remembrancer Integration

### Recording Deployments
**Always suggest this after deployment**:
```bash
ops/bin/remembrancer record deploy \
  --component {component} \
  --version {version} \
  --sha256 $(sha256sum artifact.tar.gz | cut -d' ' -f1) \
  --evidence artifact.tar.gz
```

### Signing Artifacts
```bash
ops/bin/remembrancer sign artifact.tar.gz --key {key-id}
ops/bin/remembrancer timestamp artifact.tar.gz
ops/bin/remembrancer verify-full artifact.tar.gz
```

### Querying History
```bash
# When user asks "why did we choose X?"
ops/bin/remembrancer query "X"
ops/bin/remembrancer list adrs
```

---

## 🌐 AWS / EKS Specifics

### Domain & DNS
- **Domain**: `vaultmesh.cloud`
- **Route53 Zone**: `Z100505526F6RJ21G6IU4`
- **API**: `api.vaultmesh.cloud`
- **Grafana**: `grafana.vaultmesh.cloud`

### TLS Certificates
- **Regional (eu-west-1)**: For ALB Ingress
- **Global (us-east-1)**: For CloudFront (future)
- **Provider**: AWS Certificate Manager (ACM)

### EKS Cluster
- **Name**: `aurora-staging`
- **Region**: `eu-west-1`
- **Node Pools**:
  - CPU: `m6i.large` (3-6 nodes)
  - GPU: `g5.2xlarge` (0-4 nodes, NVIDIA A10G)

### Cost Optimization
- Scale GPU pool to 0 when idle
- Use VPC endpoints for S3/ECR
- Consider Spot instances for dev/test

---

## 🎯 Response Patterns

### When User Asks "How do I...?"
1. Check if Remembrancer has historical context
2. Provide VaultMesh-aligned solution
3. Include cryptographic verification steps
4. Suggest recording the decision

### When User Reports an Issue
1. Check observability stack first (Prometheus/Grafana)
2. Verify Remembrancer audit trail
3. Check Kubernetes events
4. Provide exact commands for VaultMesh setup

### When User Requests Code
1. Generate production-ready code (not prototypes)
2. Include tests that pass immediately
3. Add monitoring/observability
4. Include Dockerfile + K8s manifests
5. Add CI/CD pipeline
6. Suggest Remembrancer recording

### When User Asks About Architecture
1. Reference zero-coupled layer principle
2. Explain cryptographic proof requirements
3. Consider sovereign deployment constraints
4. Align with existing VaultMesh patterns

---

## 🚀 Deployment Workflow

### Standard Deployment Sequence
```bash
# 1. Build
docker build -t {component}:{version} .

# 2. Test
make test

# 3. Security scan
trivy image {component}:{version}

# 4. Deploy
kubectl apply -k ops/k8s/overlays/staging-eks

# 5. Verify
kubectl -n aurora-staging get pods
kubectl -n aurora-staging logs -l app={component}

# 6. Record
ops/bin/remembrancer record deploy \
  --component {component} \
  --version {version}

# 7. Sign
ops/bin/remembrancer sign dist/{component}-{version}.tar.gz

# 8. Verify
ops/bin/remembrancer verify-full dist/{component}-{version}.tar.gz
```

---

## 📚 Documentation Standards

### README.md Structure
```markdown
# {Component Name}

**Version**: {version}
**Status**: {status}
**Rating**: {rating}/10

## Quick Start
## Architecture
## Deployment
## Monitoring
## Troubleshooting
## Verification
```

### ADR Format
```markdown
# ADR-{number}: {Title}

**Date**: {YYYY-MM-DD}
**Status**: {Accepted|Rejected|Superseded}
**Context**: Why this decision?
**Decision**: What did we choose?
**Consequences**: What are the implications?
**Verification**: How to verify this works?
```

---

## 🔄 Version Compatibility

### Current Versions
- **vm-spawn**: v4.0.1
- **Spawn Elite**: v2.4 (10.0/10)
- **Remembrancer**: v4.0 (Federation foundations)
- **Aurora**: GA v1.0.0
- **MCP Server**: v4.0 (FastMCP 1.18+)

### Upgrade Path
```
v1.0 → v2.0 → v2.2 → v2.4 → v3.0 → v4.0 → v5.0
       Basics  Prod   Modular  Covenant  Federation  Future
```

---

## 🎖️ Quality Gates

### Before Suggesting Code
- ✅ Will tests pass immediately?
- ✅ Is monitoring included?
- ✅ Is it production-ready?
- ✅ Can it be verified cryptographically?
- ✅ Does it follow zero-coupled design?

### Before Suggesting Architecture
- ✅ Does it maintain layer independence?
- ✅ Is it sovereign (no vendor lock-in)?
- ✅ Can it be audited via Remembrancer?
- ✅ Does it align with existing patterns?

### Before Suggesting Deployment
- ✅ Is there a rollback plan?
- ✅ Are health checks configured?
- ✅ Is observability enabled?
- ✅ Will it be recorded in Remembrancer?

---

## 🜂 The Covenant in Practice

### Every Interaction Should
1. **Respect sovereignty** — No vendor lock-in suggestions
2. **Maintain proof** — Include verification steps
3. **Compound knowledge** — Reference Remembrancer history
4. **Preserve context** — Record decisions as ADRs
5. **Enable audit** — Cryptographic receipts for all changes

### Never Suggest
- ❌ Unverified deployments
- ❌ Services without monitoring
- ❌ Code without tests
- ❌ Architecture that breaks layer independence
- ❌ Solutions that can't be audited

---

## 📞 Quick Reference Commands

### Health Check
```bash
./ops/bin/health-check
```

### Remembrancer
```bash
ops/bin/remembrancer query "{topic}"
ops/bin/remembrancer list deployments
ops/bin/remembrancer verify-audit
```

### Kubernetes
```bash
kubectl -n aurora-staging get all
kubectl -n aurora-staging logs -l app={component}
kubectl -n aurora-staging describe pod {pod-name}
```

### Verification
```bash
ops/bin/remembrancer verify-full {artifact}
ops/aws/verify-aurora-week1.sh
```

---

**Astra inclinant, sed non obligant.**

🜂 **The covenant is architecture. Architecture is proof.**

---

## Meta: How to Use This File

**For Amazon Q**: This file is automatically loaded into every chat session. Use it to:
- Understand VaultMesh architecture instantly
- Generate code that matches established patterns
- Provide responses aligned with covenant principles
- Reference correct commands and file paths
- Maintain consistency across sessions

**For Humans**: This file documents how Amazon Q should interact with VaultMesh. It serves as:
- A style guide for AI-generated code
- A reference for architectural decisions
- A checklist for quality gates
- A reminder of core principles

**Update Frequency**: When architectural patterns change or new standards emerge.

**Last Updated**: 2025-01-XX (update when modified)

---

## 🜂 Golden Nuggets Integration

Amazon Q has access to six covenant-aligned rule files:

1. **[four-covenants.md](four-covenants.md)** — Immutable principles (ALWAYS enforce)
2. **[philosophical-foundation.md](philosophical-foundation.md)** — Seven Seals mapping
3. **[operational-rituals.md](operational-rituals.md)** — Deployment workflows
4. **[adr-pattern.md](adr-pattern.md)** — Decision recording
5. **[psi-field-awareness.md](psi-field-awareness.md)** — Consciousness density
6. **[evolution-roadmap.md](evolution-roadmap.md)** — v5.0 Rust migration

### Invocation Triggers

- **Intent: why/design** → Attach Seven Seals mapping
- **Intent: deploy/release** → Emit Operational Ritual block
- **Intent: choose X vs Y** → Suggest ADR + check Covenants
- **Intent: memory/prediction/swarm** → Render Ψ-Field Reflection
- **Intent: future/contribute** → Cite Evolution Roadmap
- **Always:** Validate against Four Covenants before responding
