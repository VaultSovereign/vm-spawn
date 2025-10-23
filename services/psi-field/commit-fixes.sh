#!/bin/bash
# Commit all PSI-field audit fixes

cd /home/sovereign/vm-spawn

git add services/psi-field/src/main.py \
        services/psi-field/tests/test_backend_switch.py \
        services/psi-field/tests/test_guardian_advanced.py \
        services/psi-field/tests/test_mq_degrades_cleanly.py \
        services/psi-field/docker-compose.psiboth.yml \
        services/psi-field/k8s/psi-both.yaml \
        services/psi-field/smoke-test-dual.sh \
        services/psi-field/verify-fixes.sh \
        services/psi-field/commit-fixes.sh \
        services/psi-field/DUAL_BACKEND_GUIDE.md \
        services/psi-field/AUDIT_FIXES_SUMMARY.md \
        services/psi-field/QUICKREF.md \
        services/psi-field/READY_TO_DEPLOY.md

git commit -m "[psi-field] Fix audit gaps: unify startup, env-driven PSI_BACKEND, AdvancedGuardian default, /guardian/statistics + dual-backend deploy"

echo "✅ Committed. Ready to push."
