# 🚦 VaultMesh MCP Launch – Go / No-Go Plan

The strategist ➜ executor ➜ auditor loop may only move from simulation to live control when every prerequisite, integration check, and contingency path is verified. Use this plan for each promotion (staging → production or dry-run → live).

---

## 1. Scope & Ownership
- **Controller:** MCP Operations Lead (owns the go call)
- **Support:** Remembrancer operator, Spawn Elite operator, Observability engineer, Security officer
- **Window:** 30 minute execution window; abort if window closes

---

## 2. Prerequisite Checklist (must be ✅ before the go/no-go poll)

| Requirement | Verification |
|-------------|--------------|
| Remembrancer CLI reachable | `REMEMBRANCER_PATH=/home/sovereign/vm-spawn/ops/bin/remembrancer ./ops/bin/remembrancer verify-audit` |
| Telemetry target online | `PROMETHEUS_URL` responds at `/api/v1/status/runtimeinfo` |
| Kubernetes context ready | `kubectl --context ${DEPLOY_CONTEXT} get ns ${DEPLOY_NAMESPACE}` |
| Spawn path linked | `ls /home/sovereign/vm-spawn/services` |
| MCP database writeable | `sqlite3 data/mcp.sqlite "pragma quick_check;"` |
| Agent API running | `curl http://localhost:5000/api/agent/mcp/status` |

Document evidence in the launch log before continuing.

---

## 3. Go / No-Go Poll

1. **Controller** reviews prerequisite log.
2. **Controller** conducts rapid poll:
   - Remembrancer Ops
   - Spawn Ops
   - Observability
   - Security
3. Any “no-go” or silence = automatic hold. Record reason, remediate, restart poll.

### Go Criteria
- All prerequisites ✅
- ChatKit workflow ID and API keys loaded (`CHATKIT_WORKFLOW_ID`, `OPENAI_API_KEY`)
- `npm run dev` (or `npm run start`) serving `/api/backend/status` with `mode: "production"`
- `data/mcp.sqlite` contains plan records after dry-run rehearsal

### No-Go Triggers
- Missing receipts or Merkle verification failures
- Telemetry stale (`status` returns `flatlined` or `unavailable`)
- MPC storage locked or unwritable
- Security officer veto (credential exposure, unsealed Remembrancer key)

---

## 4. Launch Runbook (after a unanimous “go”)

1. **Switch to live Remembrancer**  
   `export REMEMBRANCER_PATH=/home/sovereign/vm-spawn/ops/bin/remembrancer`
2. **Set deployment namespace/region**  
   `export DEPLOY_NAMESPACE=aurora-staging`  
   `export DEPLOY_REGION=us-west-1`
3. **Restart stack for clean env**  
   ```bash
   npm install
   npm run dev
   ```
4. **Health smoke**  
   - `curl http://localhost:5000/api/system/health`
   - `curl http://localhost:5000/api/agent/mcp/status`
5. **Execute MCP rehearsal** (phase 1 dry-run with `dryRun: true`)
6. **Execute live plan**  
   - Strategist: POST `/api/agent/mcp/strategist/plan`  
   - Executor: POST `/api/agent/mcp/executor/run` (per phase)  
   - Auditor: POST `/api/agent/mcp/auditor/verify`
7. **Record Merkle update**  
   - `./ops/bin/remembrancer verify-audit`  
   - Append Merkle root + receipt paths to launch log

---

## 5. Contingency / Rollback

| Trigger | Immediate Action | Follow-up |
|---------|------------------|-----------|
| Executor returns `status: failed` | Abort plan, set MCP status to `hold`, notify Remembrancer Ops | Run auditor with `checks: ["health"]`, collect logs |
| Remembrancer verification fails | Switch `REMEMBRANCER_PATH` back to simulator, stop executor | Restore from last known good receipt, re-run audit |
| Telemetry outage | Flip `PROMETHEUS_URL` to mock, pause deployments | Engage Observability, resume only after SLO recovered |
| Security alert (key leak, TSA mismatch) | Immediate no-go, revoke credentials | Invoke operator runbook (see `DAO_GOVERNANCE_PACK/operator-runbook.md`) |

---

## 6. Post-Launch Closeout
1. Auditor reruns with `checks: ["receipts", "health", "compliance"]`.
2. Capture final Merkle root and attach receipts to `ops/receipts/`.
3. Update launch log with:
   - Plan ID and phases
   - Receipts stored
   - Merkle root
   - Any deviations or incidents
4. Update documentation:
   - `VAULTMESH_MCP_AGENT_GUIDE.md` launch evidence section
   - `MASTER_DELIVERY_INDEX.md` status badge

---

## 7. References
- `vaultmesh-us-mcp/MCP_SUPER_AGENTS_CONFIG.md` – tool endpoints & schemas
- `vaultmesh-us-mcp/VAULTMESH_MCP_AGENT_GUIDE.md` – operator walkthrough
- `vaultmesh-us-mcp/PSI_MCP_TOOLS_CONFIG.md` – PSI-specific tool wiring
- `vaultmesh-us-mcp/MCP_AGENT_COMPLETE_SUMMARY.md` – package overview

Keep this plan versioned with each infrastructure release; update after every launch to reflect new learnings or integration changes.

