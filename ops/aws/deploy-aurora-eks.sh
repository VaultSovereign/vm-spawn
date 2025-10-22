#!/usr/bin/env bash
# Aurora EKS Deployment Script
# Complete runbook automation for AWS EKS deployment with vaultmesh.cloud DNS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration (override via environment variables)
export AWS_REGION="${AWS_REGION:-eu-west-1}"
export EKS_CLUSTER="${EKS_CLUSTER:-aurora-staging}"
export HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-Z100505526F6RJ21G6IU4}"
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"  # Must be set by user
export ACM_REGIONAL_ARN="${ACM_REGIONAL_ARN:-arn:aws:acm:eu-west-1:ACCOUNT_ID:certificate/bc354064-f711-4d35-a2b6-326aa3da830b}"

# Deployment options
SKIP_CLUSTER_CREATE="${SKIP_CLUSTER_CREATE:-false}"
SKIP_ALB_CONTROLLER="${SKIP_ALB_CONTROLLER:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"
SKIP_DNS="${SKIP_DNS:-false}"
USE_EXTERNAL_DNS="${USE_EXTERNAL_DNS:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=0

    # Check required tools
    for tool in aws kubectl eksctl helm jq; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed"
            missing=$((missing + 1))
        fi
    done

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        missing=$((missing + 1))
    else
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            log_info "Detected AWS Account ID: $AWS_ACCOUNT_ID"
        fi
    fi

    # Check if ACM cert exists
    if aws acm describe-certificate --certificate-arn "$ACM_REGIONAL_ARN" --region "$AWS_REGION" &> /dev/null; then
        log_success "ACM certificate verified: $ACM_REGIONAL_ARN"
    else
        log_warn "ACM certificate not found or invalid - you may need to update ACM_REGIONAL_ARN"
    fi

    if [ $missing -gt 0 ]; then
        log_error "Missing $missing required prerequisites"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Step 1: Create EKS cluster
create_eks_cluster() {
    if [ "$SKIP_CLUSTER_CREATE" = "true" ]; then
        log_warn "Skipping EKS cluster creation (SKIP_CLUSTER_CREATE=true)"
        return
    fi

    log_info "Step 1: Creating EKS cluster..."

    if kubectl cluster-info --context "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${EKS_CLUSTER}" &> /dev/null; then
        log_warn "Cluster $EKS_CLUSTER already exists. Skipping creation."
    else
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would create cluster: eksctl create cluster -f ../../eks-aurora-staging.yaml"
        else
            eksctl create cluster -f ../../eks-aurora-staging.yaml
            log_success "Cluster created successfully"
        fi
    fi

    log_info "Updating kubeconfig..."
    aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"

    log_info "Verifying nodes..."
    kubectl get nodes

    log_info "Installing NVIDIA device plugin for GPU nodes..."
    if [ "$DRY_RUN" = "false" ]; then
        kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/nvidia-device-plugin.yml
    fi

    log_success "Step 1 complete: EKS cluster ready"
}

# Step 2: Install AWS Load Balancer Controller
install_alb_controller() {
    if [ "$SKIP_ALB_CONTROLLER" = "true" ]; then
        log_warn "Skipping ALB controller installation (SKIP_ALB_CONTROLLER=true)"
        return
    fi

    log_info "Step 2: Installing AWS Load Balancer Controller..."

    # Add Helm repo
    helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
    helm repo update

    # Get VPC ID
    local vpc_id
    vpc_id=$(aws eks describe-cluster --name "$EKS_CLUSTER" --region "$AWS_REGION" \
        --query "cluster.resourcesVpcConfig.vpcId" --output text)
    log_info "Detected VPC: $vpc_id"

    # Create IAM service account
    log_info "Creating IAM service account for ALB controller..."
    if [ "$DRY_RUN" = "false" ]; then
        eksctl create iamserviceaccount \
            --cluster "$EKS_CLUSTER" --region "$AWS_REGION" \
            --namespace kube-system \
            --name aws-load-balancer-controller \
            --attach-policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
            --override-existing-serviceaccounts --approve || log_warn "IAM service account may already exist"
    fi

    # Install Helm chart
    log_info "Installing ALB controller Helm chart..."
    if [ "$DRY_RUN" = "false" ]; then
        helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName="$EKS_CLUSTER" \
            --set region="$AWS_REGION" \
            --set vpcId="$vpc_id" \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller

        log_info "Waiting for ALB controller to be ready..."
        kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m
    fi

    log_success "Step 2 complete: ALB controller installed"
}

# Step 3: Deploy Aurora staging overlay
deploy_aurora_staging() {
    log_info "Step 3: Deploying Aurora staging overlay..."

    # Update ACM ARN in ingress manifests
    log_info "Updating ACM certificate ARN in ingress manifests..."
    local ingress_dir="../../ops/k8s/overlays/staging-eks"

    for ingress_file in "$ingress_dir"/ingress-*.yaml; do
        if [ -f "$ingress_file" ]; then
            if [ "$DRY_RUN" = "false" ]; then
                sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" "$ingress_file"
                log_info "Updated: $(basename "$ingress_file")"
            else
                log_info "[DRY RUN] Would update: $(basename "$ingress_file")"
            fi
        fi
    done

    # Apply Kustomize overlay
    log_info "Applying Kustomize overlay..."
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: kubectl apply -k $ingress_dir"
        kubectl kustomize "$ingress_dir"
    else
        kubectl apply -k "$ingress_dir"

        log_info "Waiting for deployments to be ready..."
        kubectl -n aurora-staging wait --for=condition=available --timeout=5m deployment --all || log_warn "Some deployments may not be ready yet"
    fi

    # Show deployed resources
    log_info "Deployed resources:"
    kubectl -n aurora-staging get deploy,svc,ingress

    log_success "Step 3 complete: Aurora staging deployed"
}

# Step 4: Install Prometheus & Grafana
install_monitoring() {
    if [ "$SKIP_MONITORING" = "true" ]; then
        log_warn "Skipping monitoring installation (SKIP_MONITORING=true)"
        return
    fi

    log_info "Step 4: Installing Prometheus & Grafana..."

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo update

    # Install Prometheus
    log_info "Installing Prometheus..."
    if [ "$DRY_RUN" = "false" ]; then
        if [ -f "../aws/prometheus-values.yaml" ]; then
            helm upgrade --install prometheus prometheus-community/prometheus \
                -n aurora-staging -f ../aws/prometheus-values.yaml --wait
        else
            helm upgrade --install prometheus prometheus-community/prometheus \
                -n aurora-staging --wait
        fi
    fi

    # Install Grafana
    log_info "Installing Grafana..."
    if [ "$DRY_RUN" = "false" ]; then
        if [ -f "../aws/grafana-values.yaml" ]; then
            helm upgrade --install grafana grafana/grafana \
                -n aurora-staging -f ../aws/grafana-values.yaml --wait
        else
            helm upgrade --install grafana grafana/grafana \
                -n aurora-staging --wait
        fi

        # Get Grafana admin password
        log_info "Grafana admin password:"
        kubectl get secret --namespace aurora-staging grafana -o jsonpath="{.data.admin-password}" | base64 --decode
        echo ""
    fi

    log_success "Step 4 complete: Monitoring installed"
}

# Step 5: Configure DNS
configure_dns() {
    if [ "$SKIP_DNS" = "true" ]; then
        log_warn "Skipping DNS configuration (SKIP_DNS=true)"
        return
    fi

    log_info "Step 5: Configuring DNS..."

    # Wait for ALB to be provisioned
    log_info "Waiting for API Ingress ALB to be provisioned..."
    local retries=30
    local alb_dns=""

    for ((i=1; i<=retries; i++)); do
        alb_dns=$(kubectl -n aurora-staging get ing aurora-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$alb_dns" ]; then
            log_success "ALB provisioned: $alb_dns"
            break
        fi
        log_info "Waiting for ALB... ($i/$retries)"
        sleep 10
    done

    if [ -z "$alb_dns" ]; then
        log_error "ALB not provisioned after $retries attempts. Check kubectl -n aurora-staging describe ing aurora-api"
        return 1
    fi

    if [ "$USE_EXTERNAL_DNS" = "true" ]; then
        log_info "Using ExternalDNS for automatic DNS management"
        log_info "Ensure ExternalDNS is installed and configured"
        # ExternalDNS will automatically create records based on ingress annotations
    else
        log_info "Creating Route53 alias record for api.vaultmesh.cloud..."

        # ALB HostedZoneId for eu-west-1 is Z32O12XQLNTSW2
        local alb_zone_id="Z32O12XQLNTSW2"

        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would create Route53 record for api.vaultmesh.cloud -> $alb_dns"
        else
            aws route53 change-resource-record-sets \
                --hosted-zone-id "$HOSTED_ZONE_ID" \
                --change-batch "{
                    \"Changes\": [{
                        \"Action\": \"UPSERT\",
                        \"ResourceRecordSet\": {
                            \"Name\": \"api.vaultmesh.cloud\",
                            \"Type\": \"A\",
                            \"AliasTarget\": {
                                \"HostedZoneId\": \"${alb_zone_id}\",
                                \"DNSName\": \"dualstack.${alb_dns}\",
                                \"EvaluateTargetHealth\": false
                            }
                        }
                    }]
                }"
            log_success "DNS record created for api.vaultmesh.cloud"
        fi
    fi

    # Same for Grafana
    local grafana_alb_dns
    grafana_alb_dns=$(kubectl -n aurora-staging get ing aurora-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

    if [ -n "$grafana_alb_dns" ] && [ "$USE_EXTERNAL_DNS" = "false" ]; then
        log_info "Creating Route53 record for grafana.vaultmesh.cloud..."
        if [ "$DRY_RUN" = "false" ]; then
            aws route53 change-resource-record-sets \
                --hosted-zone-id "$HOSTED_ZONE_ID" \
                --change-batch "{
                    \"Changes\": [{
                        \"Action\": \"UPSERT\",
                        \"ResourceRecordSet\": {
                            \"Name\": \"grafana.vaultmesh.cloud\",
                            \"Type\": \"A\",
                            \"AliasTarget\": {
                                \"HostedZoneId\": \"Z32O12XQLNTSW2\",
                                \"DNSName\": \"dualstack.${grafana_alb_dns}\",
                                \"EvaluateTargetHealth\": false
                            }
                        }
                    }]
                }"
            log_success "DNS record created for grafana.vaultmesh.cloud"
        fi
    fi

    log_success "Step 5 complete: DNS configured"
}

# Step 6: Verify deployment
verify_deployment() {
    log_info "Step 6: Verifying deployment..."

    # DNS resolution check
    log_info "Checking DNS resolution..."
    for domain in api.vaultmesh.cloud grafana.vaultmesh.cloud; do
        if dig +short "$domain" | grep -q .; then
            log_success "DNS resolves: $domain"
        else
            log_warn "DNS not yet propagated: $domain (may take a few minutes)"
        fi
    done

    # HTTPS check
    log_info "Checking HTTPS endpoints (may take a few minutes for cert validation)..."
    sleep 30  # Give ALB time to configure TLS

    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://api.vaultmesh.cloud/health 2>/dev/null | grep -q "200"; then
        log_success "API health check passed: https://api.vaultmesh.cloud/health"
    else
        log_warn "API not yet responding (may still be starting up)"
    fi

    # Show next steps
    log_info ""
    log_info "=========================================="
    log_info "Deployment Summary"
    log_info "=========================================="
    log_info "Cluster: $EKS_CLUSTER"
    log_info "Region: $AWS_REGION"
    log_info "Namespace: aurora-staging"
    log_info ""
    log_info "Endpoints:"
    log_info "  API: https://api.vaultmesh.cloud"
    log_info "  Grafana: https://grafana.vaultmesh.cloud"
    log_info "  Prometheus: http://prometheus.aurora-staging.internal (VPC-only)"
    log_info ""
    log_info "Next Steps:"
    log_info "  1. Run: ./verify-aurora-week1.sh"
    log_info "  2. Import Grafana dashboard: ops/grafana/grafana-kpi-panels-patch.json"
    log_info "  3. Monitor metrics: make slo-report"
    log_info "  4. Generate Week 1 report after 72h soak"
    log_info "=========================================="

    log_success "Deployment complete!"
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Aurora EKS Deployment"
    log_info "=========================================="
    log_info "Cluster: $EKS_CLUSTER"
    log_info "Region: $AWS_REGION"
    log_info "DNS Zone: $HOSTED_ZONE_ID"
    log_info "Dry Run: $DRY_RUN"
    log_info "=========================================="

    if [ "$DRY_RUN" = "true" ]; then
        log_warn "Running in DRY RUN mode - no changes will be made"
    fi

    check_prerequisites
    create_eks_cluster
    install_alb_controller
    deploy_aurora_staging
    install_monitoring
    configure_dns
    verify_deployment

    log_success "All steps completed successfully!"
}

# Run main
main "$@"
