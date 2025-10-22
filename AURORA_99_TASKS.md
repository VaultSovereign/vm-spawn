# 🚀 Aurora 9.9/10 Task List

**Timeline:** Nov 12 - Dec 3, 2025 (3 weeks)  
**Target:** +0.4 points → 9.9/10

---

## 📋 Week 1: Operational Excellence

### Target: Real metrics flowing

- [ ] **W1-1:** Deploy Aurora staging overlay to K8s cluster
  - Command: `kubectl apply -k ops/k8s/overlays/staging`
  - Verify: `kubectl get pods -n aurora-staging`

- [ ] **W1-2:** Configure Prometheus exporters for Aurora metrics
  - Files: `scripts/aurora-metrics-exporter.py`
  - Verify: `curl http://localhost:9090/metrics | grep treaty_`

- [ ] **W1-3:** Run 72h staging soak test with real workloads
  - Command: `./scripts/smoke-e2e.sh --duration 72h`
  - Monitor: Grafana dashboard at `http://localhost:3000`

- [ ] **W1-4:** Populate `canary_slo_report.json` with real metrics
  - Script: `./scripts/slo-report.sh > canary_slo_report.json`
  - Verify: No null values in metrics object

- [ ] **W1-5:** Publish first Grafana dashboard screenshot
  - Screenshot: `docs/aurora-staging-metrics.png`
  - Show: 72h of green SLOs

- [ ] **W1-6:** Generate and commit first ledger snapshot
  - Command: `./scripts/ledger-snapshot.sh`
  - File: `ops/ledger/snapshots/2025-11-18.json`

**Completion Gate:** All 4 KPIs meet targets, 72h uptime proven

---

## 📋 Week 2: Automation Hardening

### Target: CI enforces covenants

- [ ] **W2-1:** GitHub Action: auto-publish Merkle root on merge
  - File: `.github/workflows/covenant-enforce.yml` (merkle-publish job)
  - Test: Merge PR, verify `docs/REMEMBRANCER.md` auto-updates

- [ ] **W2-2:** GitHub Action: covenant validation as required check
  - File: `.github/workflows/covenant-enforce.yml` (covenant-validation job)
  - Test: Create PR with broken covenant, verify CI blocks

- [ ] **W2-3:** GitHub Action: smoke test suite on every PR
  - File: `.github/workflows/covenant-enforce.yml` (smoke-test job)
  - Test: Create PR, verify 26/26 tests run automatically

- [ ] **W2-4:** Configure automatic GPG signing for release tags
  - Setup: Add GPG key to GitHub secrets
  - Test: Create release tag, verify auto-signing

- [ ] **W2-5:** Pre-commit hook: forbid merge if smoke test fails
  - File: `.git/hooks/pre-commit`
  - Test: Stage broken change, verify commit blocked

- [ ] **W2-6:** Document CI pipeline in `docs/CI_AUTOMATION.md`
  - Sections: Required checks, automatic actions, troubleshooting
  - Review: Ensure reproducible by external reader

**Completion Gate:** PRs cannot merge without passing checks, Merkle root auto-publishes

---

## 📋 Week 3: Federation Proof

### Target: Two nodes sync successfully

- [ ] **W3-1:** Deploy second Remembrancer node (peer B) locally
  - Location: `/tmp/vm-spawn-peer`
  - Command: `git clone . /tmp/vm-spawn-peer && cd /tmp/vm-spawn-peer`

- [ ] **W3-2:** Execute federation sync between node A ↔ node B
  - Start Node A: `REMEMBRANCER_MCP_HTTP=1 python ops/mcp/remembrancer_server.py`
  - Start Node B: `cd /tmp/vm-spawn-peer && MCP_PORT=8002 ...`
  - Sync: `./ops/bin/remembrancer federation sync --peer http://localhost:8002/mcp`

- [ ] **W3-3:** Verify deterministic merge: same inputs = same root
  - Test: Run sync twice, compare Merkle roots
  - Expected: Identical roots both times

- [ ] **W3-4:** Generate federation receipt with both signatures
  - File: `ops/receipts/federation/2025-11-26-sync.receipt`
  - Verify: Contains signatures from both Node A and Node B

- [ ] **W3-5:** Document federation protocol in `docs/FEDERATION_GUIDE.md`
  - Sections: Overview, setup, sync, verification
  - Include: Reproducible command examples

- [ ] **W3-6:** Add federation smoke test to `SMOKE_TEST.sh`
  - Test 27: Federation sync dry-run
  - Command: `./ops/bin/remembrancer federation sync --self-test`

**Completion Gate:** Two nodes sync, dual-signed receipt, documentation complete

---

## 📋 Hygiene & Polish (Ongoing)

### Documentation

- [ ] **H1:** Archive completion markers
  ```bash
  mkdir -p archive/completion-records/v4-aurora
  mv ⚡_*.txt 🎉_*.txt 🎖️_*.txt 🛡️_*.txt 🜂_*.txt archive/completion-records/v4-aurora/
  ```

- [ ] **H2:** Archive superseded version docs
  ```bash
  mkdir -p docs/releases/
  mv V2.*.md V3.0_*.md V4.0_*.md docs/releases/
  ```

- [ ] **H3:** Clean root directory
  - Keep: `README.md`, `START_HERE.md`, `AURORA_REPOSITORY_SEAL.md`, `VERSION_TIMELINE.md`
  - Archive: Version-specific docs

### Git

- [ ] **H4:** Add simulator output to `.gitignore`
  ```bash
  echo "sim/multi-provider-routing-simulator/out/" >> .gitignore
  ```

- [ ] **H5:** Commit untracked Aurora files
  ```bash
  git add AURORA_REPOSITORY_SEAL.md canary_slo_report.json
  git commit -m "chore(aurora): finalize GA v1.0.0 ecosystem"
  ```

- [ ] **H6:** Remove deleted `.obsidian` files
  ```bash
  git add .obsidian/
  git commit -m "chore: remove obsolete Obsidian config"
  ```

### Genesis

- [ ] **H7:** Seal Genesis ceremony
  ```bash
  export REMEMBRANCER_KEY_ID=6E4082C6A410F340
  ./ops/bin/tsa-bootstrap
  ./ops/bin/genesis-seal
  ```

- [ ] **H8:** Verify Genesis artifact
  ```bash
  ./ops/bin/rfc3161-verify dist/genesis.tar.gz
  # Expected: ✅ RFC3161 timestamp valid
  ```

- [ ] **H9:** Publish Merkle root
  ```bash
  ./ops/bin/publish-merkle-root.sh
  git add docs/REMEMBRANCER.md
  git commit -m "chore(merkle): publish canonical root"
  ```

**Completion Gate:** Zero untracked files, root directory pristine

---

## 📊 Progress Tracking

### Week 1: Operational Excellence
- [ ] 0/6 tasks complete
- [ ] Metrics flowing: NO
- [ ] 72h uptime: NO
- [ ] Status: NOT STARTED

### Week 2: Automation Hardening
- [ ] 0/6 tasks complete
- [ ] CI enforcing: NO
- [ ] Merkle auto-publish: NO
- [ ] Status: NOT STARTED

### Week 3: Federation Proof
- [ ] 0/6 tasks complete
- [ ] Two nodes synced: NO
- [ ] Receipt dual-signed: NO
- [ ] Status: NOT STARTED

### Hygiene & Polish
- [ ] 0/9 tasks complete
- [ ] Git status clean: NO
- [ ] Genesis sealed: NO
- [ ] Status: NOT STARTED

---

## 🎯 Final Acceptance Criteria (9.9/10)

- [ ] **Smoke tests:** 27/27 passing (added federation test)
- [ ] **Git status:** Zero untracked files
- [ ] **Documentation:** Root directory pristine, releases archived
- [ ] **Genesis:** `dist/genesis.tar.gz` present and verified
- [ ] **Merkle root:** Published in `docs/REMEMBRANCER.md`
- [ ] **CI enforcement:** Required checks live on GitHub
- [ ] **Aurora metrics:** 72h production data in `canary_slo_report.json`
- [ ] **Federation:** Working sync with dual-signed receipt
- [ ] **Health check:** 16/16 passing
- [ ] **Covenant:** 4/4 passing (including Proof-chain with Genesis)

**When all ✅ → Aurora is 9.9/10**

---

## 📞 Daily Standup Template

```
Date: YYYY-MM-DD
Week: [1|2|3]

✅ Completed yesterday:
-

🚧 Working on today:
-

🚨 Blockers:
-

📊 Progress: X/18 tasks complete (Y%)
```

---

**Last Updated:** 2025-10-22  
**Owner:** VaultMesh Team  
**Review:** Daily
