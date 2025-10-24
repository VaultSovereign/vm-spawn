#!/usr/bin/env bash
# VaultMesh Production Infrastructure Smoke Test
# Validates GKE deployment, pod health, and service endpoints
#
# Usage:
#   ./SMOKE_TEST_PRODUCTION.sh [--cluster CLUSTER_NAME] [--namespace NAMESPACE]
#
# Environment Variables:
#   GCP_PROJECT      - GCP project ID (default: vm-spawn)
#   GCP_REGION       - GCP region (default: us-central1)
#   CLUSTER_NAME     - GKE cluster name (default: vaultmesh-minimal)
#   NAMESPACE        - K8s namespace (default: vaultmesh)
#   SKIP_AUTH        - Skip gcloud auth (default: false)
#   SKIP_INGRESS     - Skip external ingress tests (default: false)

set -euo pipefail

# Configuration
GCP_PROJECT="${GCP_PROJECT:-vm-spawn}"
GCP_REGION="${GCP_REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-vaultmesh-minimal}"
NAMESPACE="${NAMESPACE:-vaultmesh}"
SKIP_AUTH="${SKIP_AUTH:-false}"
SKIP_INGRESS="${SKIP_INGRESS:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log_header() {
    echo -e "\n${PURPLE}═══ $1 ═══${NC}\n"
}

log_test() {
    echo -e "${BLUE}TEST $((TESTS_RUN + 1)): $1${NC}"
}

log_pass() {
    echo -e "  ${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "  ${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"
}

log_info() {
    echo -e "  ℹ️  $1"
}

# Test framework
run_test() {
    local name="$1"
    local command="$2"

    ((TESTS_RUN++))
    log_test "$name"

    if eval "$command" > /dev/null 2>&1; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        return 1
    fi
}

run_test_verbose() {
    local name="$1"
    local command="$2"

    ((TESTS_RUN++))
    log_test "$name"

    local output
    if output=$(eval "$command" 2>&1); then
        log_pass "$name"
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/    /'
        fi
        return 0
    else
        log_fail "$name"
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/    /' >&2
        fi
        return 1
    fi
}

# Main tests
main() {
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🔥  VAULTMESH PRODUCTION SMOKE TEST                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_info "Project: $GCP_PROJECT"
    log_info "Region: $GCP_REGION"
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Namespace: $NAMESPACE"

    # =====================================================
    # CATEGORY 1: GCP Infrastructure
    # =====================================================
    log_header "CATEGORY 1: GCP INFRASTRUCTURE"

    if [[ "$SKIP_AUTH" != "true" ]]; then
        run_test "GCP authentication valid" \
            "gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q '.'"
    fi

    run_test "GCP project configured" \
        "gcloud config get-value project | grep -q '$GCP_PROJECT'"

    run_test_verbose "GKE cluster exists and is running" \
        "gcloud container clusters describe $CLUSTER_NAME --region=$GCP_REGION --format='value(status)' | grep -q 'RUNNING'"

    # =====================================================
    # CATEGORY 2: Kubernetes Connectivity
    # =====================================================
    log_header "CATEGORY 2: KUBERNETES CONNECTIVITY"

    run_test "kubectl configured for cluster" \
        "gcloud container clusters get-credentials $CLUSTER_NAME --region=$GCP_REGION 2>&1"

    run_test "kubectl can reach cluster" \
        "timeout 10 kubectl cluster-info 2>&1"

    run_test "Namespace $NAMESPACE exists" \
        "kubectl get namespace $NAMESPACE"

    run_test_verbose "Cluster nodes are ready" \
        "kubectl get nodes --no-headers | awk '{if (\$2 != \"Ready\") exit 1}' && kubectl get nodes"

    # =====================================================
    # CATEGORY 3: Core Services - Pod Health
    # =====================================================
    log_header "CATEGORY 3: CORE SERVICES - POD HEALTH"

    # Check scheduler
    run_test_verbose "Scheduler pod is running" \
        "kubectl get pod -n $NAMESPACE -l app=scheduler -o jsonpath='{.items[0].status.phase}' | grep -q 'Running' && kubectl get pod -n $NAMESPACE -l app=scheduler"

    run_test "Scheduler pod is ready" \
        "kubectl get pod -n $NAMESPACE -l app=scheduler -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}' | grep -q 'True'"

    # Check psi-field
    run_test_verbose "Psi-field pod is running" \
        "kubectl get pod -n $NAMESPACE -l app=psi-field -o jsonpath='{.items[0].status.phase}' | grep -q 'Running' && kubectl get pod -n $NAMESPACE -l app=psi-field"

    run_test "Psi-field pod is ready" \
        "kubectl get pod -n $NAMESPACE -l app=psi-field -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}' | grep -q 'True'"

    # Check for crash loops
    run_test "No pods in CrashLoopBackOff" \
        "! kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' | grep -q 'CrashLoopBackOff'"

    # =====================================================
    # CATEGORY 4: Service Endpoints
    # =====================================================
    log_header "CATEGORY 4: SERVICE ENDPOINTS"

    # Scheduler health endpoint
    log_test "Scheduler health endpoint responds"
    if kubectl exec -n $NAMESPACE deployment/scheduler -- curl -sf http://localhost:9091/health > /dev/null 2>&1; then
        log_pass "Scheduler /health endpoint responds"
    else
        log_fail "Scheduler /health endpoint not responding"
    fi

    # Scheduler metrics endpoint
    log_test "Scheduler metrics endpoint has data"
    if kubectl exec -n $NAMESPACE deployment/scheduler -- curl -sf http://localhost:9091/metrics 2>/dev/null | grep -q "vmsh_anchors"; then
        log_pass "Scheduler /metrics has anchor data"
    else
        log_fail "Scheduler /metrics missing anchor data"
    fi

    # Psi-field health endpoint
    log_test "Psi-field health endpoint responds"
    if kubectl exec -n $NAMESPACE deployment/psi-field -- curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        log_pass "Psi-field /health endpoint responds"
    else
        log_fail "Psi-field /health endpoint not responding"
    fi

    # =====================================================
    # CATEGORY 5: KEDA Autoscaling
    # =====================================================
    log_header "CATEGORY 5: KEDA AUTOSCALING"

    run_test "KEDA operator is running" \
        "kubectl get pod -n keda -l app.kubernetes.io/name=keda-operator -o jsonpath='{.items[0].status.phase}' | grep -q 'Running'"

    run_test "KEDA ScaledObjects exist" \
        "kubectl get scaledobject -n $NAMESPACE --no-headers | wc -l | grep -qv '^0$'"

    run_test_verbose "List KEDA ScaledObjects" \
        "kubectl get scaledobject -n $NAMESPACE -o custom-columns=NAME:.metadata.name,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicaCount,MAX:.spec.maxReplicaCount"

    # =====================================================
    # CATEGORY 6: External Ingress (Optional)
    # =====================================================
    if [[ "$SKIP_INGRESS" != "true" ]]; then
        log_header "CATEGORY 6: EXTERNAL INGRESS"

        run_test "LoadBalancer service exists" \
            "kubectl get svc -n $NAMESPACE --field-selector spec.type=LoadBalancer --no-headers | wc -l | grep -qv '^0$'"

        # Check if ingress has external IP
        log_test "Ingress has external IP assigned"
        EXTERNAL_IP=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [[ -n "$EXTERNAL_IP" ]]; then
            log_pass "Ingress external IP: $EXTERNAL_IP"
        else
            log_warn "Ingress external IP not yet assigned (may be provisioning)"
        fi

        # Check SSL certificates
        log_test "ManagedCertificate exists"
        if kubectl get managedcertificate -n $NAMESPACE --no-headers 2>/dev/null | wc -l | grep -qv '^0$'; then
            CERT_STATUS=$(kubectl get managedcertificate -n $NAMESPACE -o jsonpath='{.items[0].status.certificateStatus}' 2>/dev/null || echo "Unknown")
            if [[ "$CERT_STATUS" == "Active" ]]; then
                log_pass "SSL certificate status: Active"
            else
                log_warn "SSL certificate status: $CERT_STATUS (may be provisioning)"
            fi
        else
            log_warn "No ManagedCertificate found"
        fi
    fi

    # =====================================================
    # CATEGORY 7: Resource Utilization
    # =====================================================
    log_header "CATEGORY 7: RESOURCE UTILIZATION"

    log_test "Check pod resource usage"
    if kubectl top pods -n $NAMESPACE 2>/dev/null; then
        log_pass "Pod resource metrics available"
    else
        log_warn "Pod resource metrics not available (metrics-server may not be installed)"
    fi

    # =====================================================
    # Final Results
    # =====================================================
    echo -e "\n${PURPLE}═══ FINAL RESULTS ═══${NC}\n"

    echo -e "  Tests Run:     ${BLUE}$TESTS_RUN${NC}"
    echo -e "  Passed:        ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed:        ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        PASS_RATE=100
    else
        PASS_RATE=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    echo -e "  Pass Rate:     ${BLUE}${PASS_RATE}%${NC}"

    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}║   STATUS: ✅ PRODUCTION-READY                                   ║${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}✅ Production smoke test PASSED! All systems operational.${NC}"
        exit 0
    elif [[ $PASS_RATE -ge 80 ]]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                                                               ║${NC}"
        echo -e "${YELLOW}║   STATUS: ⚠️  DEGRADED (but mostly operational)               ║${NC}"
        echo -e "${YELLOW}║                                                               ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Some tests failed, but core infrastructure is operational.${NC}"
        exit 1
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}║   STATUS: ❌ FAILING                                           ║${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}❌ Production smoke test FAILED. Infrastructure needs attention.${NC}"
        exit 2
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-auth)
            SKIP_AUTH=true
            shift
            ;;
        --skip-ingress)
            SKIP_INGRESS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cluster NAME       GKE cluster name (default: vaultmesh-minimal)"
            echo "  --namespace NAME     K8s namespace (default: vaultmesh)"
            echo "  --skip-auth          Skip GCP auth validation"
            echo "  --skip-ingress       Skip external ingress tests"
            echo "  --help               Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  GCP_PROJECT          GCP project ID (default: vm-spawn)"
            echo "  GCP_REGION           GCP region (default: us-central1)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Run main test suite
main
