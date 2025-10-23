# PSI-Field Audit Fixes Summary

**Date:** 2025-01-XX  
**Status:** ✅ All 3 audit gaps closed

## Fixes Applied

### 1. ✅ Duplicate `startup` Handler
**Problem:** Two `@app.on_event("startup")` handlers (lines ~200 and ~500)  
**Fix:** Removed first handler, consolidated all init logic into single handler  
**File:** `src/main.py`

### 2. ✅ Backend Not Switchable by Env
**Problem:** Backend hardcoded to `SimpleBackend`  
**Fix:** Added `PSI_BACKEND` env var (simple|kalman|seasonal)  
**Files:** `src/main.py`  
**Usage:**
```bash
export PSI_BACKEND=kalman  # or seasonal|simple
```

### 3. ✅ Basic Guardian Active
**Problem:** Using basic Guardian instead of AdvancedGuardian  
**Fix:** Import AdvancedGuardian by default, fallback to basic  
**Files:** `src/main.py`  
**Result:** `GUARDIAN_KIND = "advanced"` by default

### 4. ✅ Bonus: `/guardian/statistics` Endpoint
**Problem:** No ops endpoint for guardian stats  
**Fix:** Added `GET /guardian/statistics` returning kind + stats  
**Files:** `src/main.py`

## Tests Added

1. **`test_backend_switch.py`** — Verify PSI_BACKEND env switching
2. **`test_guardian_advanced.py`** — Verify /guardian/statistics endpoint
3. **`test_mq_degrades_cleanly.py`** — Verify graceful MQ degradation

Run: `cd services/psi-field && pytest -q`

## Dual-Backend Deployment

**New artifacts:**
- `docker-compose.psiboth.yml` — Run Kalman + Seasonal side-by-side
- `k8s/psi-both.yaml` — K8s manifests for both backends
- `smoke-test-dual.sh` — Quick smoke test script
- `DUAL_BACKEND_GUIDE.md` — Complete deployment guide

**Quick start:**
```bash
docker compose -f docker-compose.psiboth.yml up -d --build
sleep 10
./smoke-test-dual.sh
```

**Endpoints:**
- Kalman: http://localhost:8001
- Seasonal: http://localhost:8002
- RabbitMQ: http://localhost:15672 (guest/guest)

## Commit & Push

```bash
./commit-fixes.sh
git push
```

## Verification Checklist

- [ ] `GET /health` → 200
- [ ] `POST /step` with `PSI_BACKEND=kalman` → returns `"Psi"`
- [ ] `POST /step` with `PSI_BACKEND=seasonal` → returns `"Psi"`
- [ ] `GET /guardian/statistics` → returns `"kind": "advanced"`
- [ ] RabbitMQ receives telemetry on `swarm.<AGENT_ID>.telemetry`
- [ ] Remembrancer records anchors when `_anchor` present
- [ ] Both agents publish to different routing keys

## Next Steps (Optional)

1. **Prometheus metrics:** Add `/metrics` with `psi_psi`, `psi_pe`, `psi_h`, `guardian_interventions_total`
2. **Coordinator TAM:** Temporal Alignment Matrix for soft resync
3. **SQLite Remembrancer:** Swap JSONL → SQLite when anchors > 1e6

---

**Astra inclinant, sed non obligant.**

🜂 **The covenant is architecture. Architecture is proof.**
