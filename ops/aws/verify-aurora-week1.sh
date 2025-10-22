#!/usr/bin/env bash
# Aurora Week 1 Verification Script
# Validates all Week 1 deliverables for 9.65/10 target

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Configuration
export AWS_REGION="${AWS_REGION:-eu-west-1}"
export EKS_CLUSTER="${EKS_CLUSTER:-aurora-staging}"
NAMESPACE="aurora-staging"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
    log_success "$1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    log_error "$1"
    FAILED=$((FAILED + 1))
}

check_warn() {
    log_warn "$1"
    WARNINGS=$((WARNINGS + 1))
}

# Test 1: Cluster connectivity
test_cluster_connectivity() {
    log_info "Test 1: Cluster connectivity"
    if kubectl cluster-info &> /dev/null; then
        check_pass "Cluster is accessible"
    else
        check_fail "Cannot connect to cluster"
        return 1
    fi
}

# Test 2: All pods running
test_pods_running() {
    log_info "Test 2: Pod health"

    local not_running
    not_running=$(kubectl -n "$NAMESPACE" get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o json | jq -r '.items | length')

    if [ "$not_running" -eq 0 ]; then
        check_pass "All pods are running"
    else
        check_fail "$not_running pods are not running"
        kubectl -n "$NAMESPACE" get pods --field-selector=status.phase!=Running
    fi
}

# Test 3: Ingress ALB provisioned
test_ingress_alb() {
    log_info "Test 3: Ingress ALB provisioning"

    local api_alb
    api_alb=$(kubectl -n "$NAMESPACE" get ing aurora-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -n "$api_alb" ]; then
        check_pass "API ALB provisioned: $api_alb"
    else
        check_fail "API ALB not provisioned"
    fi

    local grafana_alb
    grafana_alb=$(kubectl -n "$NAMESPACE" get ing aurora-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -n "$grafana_alb" ]; then
        check_pass "Grafana ALB provisioned: $grafana_alb"
    else
        check_warn "Grafana ALB not provisioned (may be optional)"
    fi
}

# Test 4: DNS resolution
test_dns_resolution() {
    log_info "Test 4: DNS resolution"

    for domain in api.vaultmesh.cloud grafana.vaultmesh.cloud; do
        if dig +short "$domain" | grep -q .; then
            local ip
            ip=$(dig +short "$domain" | head -1)
            check_pass "$domain resolves to $ip"
        else
            check_fail "$domain does not resolve"
        fi
    done
}

# Test 5: HTTPS endpoints
test_https_endpoints() {
    log_info "Test 5: HTTPS endpoints"

    # Test API health
    local api_status
    api_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://api.vaultmesh.cloud/health 2>/dev/null || echo "000")

    if [ "$api_status" = "200" ]; then
        check_pass "API health endpoint returns 200"
    else
        check_fail "API health endpoint returns $api_status (expected 200)"
    fi

    # Test TLS certificate
    if echo | openssl s_client -connect api.vaultmesh.cloud:443 -servername api.vaultmesh.cloud 2>/dev/null | grep -q "Verify return code: 0"; then
        check_pass "API TLS certificate is valid"
    else
        check_fail "API TLS certificate validation failed"
    fi
}

# Test 6: Prometheus targets
test_prometheus_targets() {
    log_info "Test 6: Prometheus scrape targets"

    # Port-forward to Prometheus
    kubectl -n "$NAMESPACE" port-forward svc/prometheus-server 9090:80 &
    local port_forward_pid=$!
    sleep 3

    # Check targets
    local targets_up
    targets_up=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' || echo "0")

    kill $port_forward_pid 2>/dev/null || true

    if [ "$targets_up" -gt 0 ]; then
        check_pass "Prometheus has $targets_up active targets"
    else
        check_warn "Prometheus has no active targets (may still be starting)"
    fi
}

# Test 7: Grafana accessible
test_grafana_accessible() {
    log_info "Test 7: Grafana accessibility"

    # Port-forward to Grafana
    kubectl -n "$NAMESPACE" port-forward svc/grafana 3000:80 &
    local port_forward_pid=$!
    sleep 3

    local grafana_status
    grafana_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")

    kill $port_forward_pid 2>/dev/null || true

    if [ "$grafana_status" = "200" ]; then
        check_pass "Grafana is accessible"
    else
        check_fail "Grafana health check failed (status: $grafana_status)"
    fi
}

# Test 8: Metrics exporter
test_metrics_exporter() {
    log_info "Test 8: Aurora metrics exporter"

    if kubectl -n "$NAMESPACE" get deploy aurora-metrics-exporter &> /dev/null; then
        local replicas
        replicas=$(kubectl -n "$NAMESPACE" get deploy aurora-metrics-exporter -o jsonpath='{.status.readyReplicas}')

        if [ "${replicas:-0}" -gt 0 ]; then
            check_pass "Metrics exporter is running ($replicas replicas)"
        else
            check_warn "Metrics exporter has no ready replicas"
        fi
    else
        check_warn "Metrics exporter deployment not found"
    fi
}

# Test 9: GPU nodes available
test_gpu_nodes() {
    log_info "Test 9: GPU node availability"

    local gpu_nodes
    gpu_nodes=$(kubectl get nodes -l nvidia.com/gpu=true -o json | jq -r '.items | length')

    if [ "$gpu_nodes" -gt 0 ]; then
        check_pass "$gpu_nodes GPU node(s) available"
    else
        check_warn "No GPU nodes available (may be scaled to zero)"
    fi
}

# Test 10: Resource quotas
test_resource_quotas() {
    log_info "Test 10: Resource quotas and limits"

    if kubectl -n "$NAMESPACE" get resourcequota &> /dev/null; then
        check_pass "Resource quotas configured"
    else
        check_warn "No resource quotas found"
    fi

    if kubectl -n "$NAMESPACE" get limitrange &> /dev/null; then
        check_pass "Limit ranges configured"
    else
        check_warn "No limit ranges found"
    fi
}

# Test 11: PodDisruptionBudgets
test_pdb() {
    log_info "Test 11: PodDisruptionBudgets"

    local pdb_count
    pdb_count=$(kubectl -n "$NAMESPACE" get pdb -o json | jq -r '.items | length')

    if [ "$pdb_count" -gt 0 ]; then
        check_pass "$pdb_count PodDisruptionBudget(s) configured"
    else
        check_warn "No PodDisruptionBudgets found"
    fi
}

# Test 12: Network policies
test_network_policies() {
    log_info "Test 12: Network policies"

    local netpol_count
    netpol_count=$(kubectl -n "$NAMESPACE" get networkpolicy -o json | jq -r '.items | length')

    if [ "$netpol_count" -gt 0 ]; then
        check_pass "$netpol_count network polic(ies) configured"
    else
        check_warn "No network policies found"
    fi
}

# Test 13: Secrets exist
test_secrets() {
    log_info "Test 13: Required secrets"

    for secret in grafana prometheus-server; do
        if kubectl -n "$NAMESPACE" get secret "$secret" &> /dev/null; then
            check_pass "Secret exists: $secret"
        else
            check_warn "Secret not found: $secret"
        fi
    done
}

# Test 14: ConfigMaps
test_configmaps() {
    log_info "Test 14: ConfigMaps"

    for cm in aws-config aurora-bridge-scripts; do
        if kubectl -n "$NAMESPACE" get configmap "$cm" &> /dev/null; then
            check_pass "ConfigMap exists: $cm"
        else
            check_warn "ConfigMap not found: $cm (may be optional)"
        fi
    done
}

# Test 15: Week 1 SLO report
test_slo_report() {
    log_info "Test 15: SLO report data"

    if [ -f "../../canary_slo_report.json" ]; then
        # Check if report has real data (not nulls)
        local null_count
        null_count=$(jq '[.. | select(. == null)] | length' ../../canary_slo_report.json 2>/dev/null || echo "999")

        if [ "$null_count" -eq 0 ]; then
            check_pass "SLO report exists with real data"
        else
            check_warn "SLO report contains $null_count null values (may need real metrics)"
        fi
    else
        check_warn "SLO report not generated yet (run: make slo-report)"
    fi
}

# Generate report
generate_report() {
    log_info ""
    log_info "=========================================="
    log_info "Week 1 Verification Report"
    log_info "=========================================="
    log_info "Cluster: $EKS_CLUSTER"
    log_info "Namespace: $NAMESPACE"
    log_info "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    log_info ""
    log_success "Passed: $PASSED"
    log_warn "Warnings: $WARNINGS"
    log_error "Failed: $FAILED"
    log_info ""

    local total=$((PASSED + FAILED + WARNINGS))
    local score
    if [ "$total" -gt 0 ]; then
        score=$(awk "BEGIN {printf \"%.2f\", ($PASSED / $total) * 10}")
    else
        score="0.00"
    fi

    log_info "Score: $score/10.0"
    log_info ""

    if [ "$FAILED" -eq 0 ]; then
        log_success "All critical checks passed! ✓"
        log_info ""
        log_info "Week 1 Deliverables Checklist:"
        log_info "  [ ] 72h soak period completed"
        log_info "  [ ] SLO report generated with real data"
        log_info "  [ ] Grafana dashboard screenshot captured"
        log_info "  [ ] Ledger snapshot created and signed"
        log_info "  [ ] S3 backup uploaded"
        log_info ""
        log_info "Next: Continue monitoring for 72h, then generate Week 1 report"
        return 0
    else
        log_error "Some critical checks failed. Review output above."
        return 1
    fi
}

# Main
main() {
    log_info "=========================================="
    log_info "Aurora Week 1 Verification"
    log_info "=========================================="
    log_info ""

    test_cluster_connectivity || true
    test_pods_running || true
    test_ingress_alb || true
    test_dns_resolution || true
    test_https_endpoints || true
    test_prometheus_targets || true
    test_grafana_accessible || true
    test_metrics_exporter || true
    test_gpu_nodes || true
    test_resource_quotas || true
    test_pdb || true
    test_network_policies || true
    test_secrets || true
    test_configmaps || true
    test_slo_report || true

    generate_report
}

main "$@"
