#!/bin/bash
set -euo pipefail

# VaultMesh GCP Deployment Script
# Automates deployment to Google Kubernetes Engine
# Version: 1.0.0
# Date: 2025-10-23

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-vaultmesh-cluster}"
NAMESPACE="${NAMESPACE:-vaultmesh-prod}"

# Check if PROJECT_ID is set
if [ -z "${PROJECT_ID:-}" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID not set. Run: export PROJECT_ID=your-project-id"
        exit 1
    fi
fi

GCR_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh"

log_info "VaultMesh GCP Deployment"
log_info "========================"
log_info "Project: $PROJECT_ID"
log_info "Region: $REGION"
log_info "Cluster: $CLUSTER_NAME"
log_info "Namespace: $NAMESPACE"
echo ""

# Step 1: Verify prerequisites
log_info "Step 1: Verifying prerequisites..."
command -v gcloud >/dev/null 2>&1 || { log_error "gcloud not found. Install Google Cloud SDK."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl not found. Install kubectl."; exit 1; }
command -v docker >/dev/null 2>&1 || { log_error "docker not found. Install Docker."; exit 1; }
log_success "All prerequisites installed"

# Step 2: Enable GCP APIs
log_info "Step 2: Enabling required GCP APIs..."
gcloud services enable container.googleapis.com compute.googleapis.com \
    artifactregistry.googleapis.com monitoring.googleapis.com \
    --project=$PROJECT_ID 2>/dev/null || true
log_success "APIs enabled"

# Step 3: Create Artifact Registry
log_info "Step 3: Creating Artifact Registry..."
if gcloud artifacts repositories describe vaultmesh --location=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    log_warning "Artifact Registry 'vaultmesh' already exists"
else
    gcloud artifacts repositories create vaultmesh \
        --repository-format=docker \
        --location=$REGION \
        --description="VaultMesh Docker images" \
        --project=$PROJECT_ID
    log_success "Artifact Registry created"
fi

# Configure Docker auth
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Step 4: Build and push images
log_info "Step 4: Building and pushing Docker images..."

# Build Psi-Field
log_info "Building psi-field..."
cd services/psi-field
docker build -t ${GCR_REGISTRY}/psi-field:latest .
docker push ${GCR_REGISTRY}/psi-field:latest
log_success "psi-field pushed"
cd ../..

# Build Scheduler
log_info "Building scheduler..."
cd services/scheduler
docker build -t ${GCR_REGISTRY}/scheduler:latest .
docker push ${GCR_REGISTRY}/scheduler:latest
log_success "scheduler pushed"
cd ../..

# Step 5: Create GKE cluster (if not exists)
log_info "Step 5: Creating GKE cluster..."
if gcloud container clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    log_warning "Cluster '$CLUSTER_NAME' already exists"
else
    log_info "This will take 5-10 minutes..."
    gcloud container clusters create $CLUSTER_NAME \
        --region=$REGION \
        --release-channel=regular \
        --enable-stackdriver-kubernetes \
        --workload-pool="${PROJECT_ID}.svc.id.goog" \
        --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
        --network=default \
        --num-nodes=2 \
        --enable-autoscaling \
        --min-nodes=2 \
        --max-nodes=6 \
        --machine-type=n2-standard-4 \
        --disk-type=pd-standard \
        --disk-size=50 \
        --enable-autorepair \
        --enable-autoupgrade \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --project=$PROJECT_ID
    log_success "Cluster created"
fi

# Step 6: Get credentials
log_info "Step 6: Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID
log_success "Credentials configured"

# Step 7: Create namespace
log_info "Step 7: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace '$NAMESPACE' ready"

# Step 8: Deploy monitoring stack
log_info "Step 8: Deploying monitoring stack (Prometheus + Grafana)..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

# Install Prometheus stack
if helm list -n monitoring | grep -q prometheus; then
    log_warning "Prometheus stack already installed"
else
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.service.type=LoadBalancer \
        --set grafana.service.type=LoadBalancer \
        --set prometheus.prometheusSpec.retention=30d \
        --wait --timeout=10m
    log_success "Monitoring stack deployed"
fi

# Step 9: Deploy VaultMesh services
log_info "Step 9: Deploying VaultMesh services..."

# Create temporary manifests with updated images
mkdir -p /tmp/vaultmesh-deploy

# Deploy Psi-Field
cat services/psi-field/k8s/deployment.yaml | \
    sed "s|image:.*|image: ${GCR_REGISTRY}/psi-field:latest|g" > /tmp/vaultmesh-deploy/psi-field-deployment.yaml
kubectl apply -f /tmp/vaultmesh-deploy/psi-field-deployment.yaml -n $NAMESPACE

# Create Service for Psi-Field
cat > /tmp/vaultmesh-deploy/psi-field-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: psi-field
  namespace: $NAMESPACE
  labels:
    app: psi-field
spec:
  type: LoadBalancer
  selector:
    app: psi-field
  ports:
    - port: 8000
      targetPort: 8000
      protocol: TCP
      name: http
EOF
kubectl apply -f /tmp/vaultmesh-deploy/psi-field-service.yaml

log_success "Psi-Field deployed"

# Deploy Scheduler
cat services/scheduler/k8s/deployment.yaml | \
    sed "s|image:.*|image: ${GCR_REGISTRY}/scheduler:latest|g" > /tmp/vaultmesh-deploy/scheduler-deployment.yaml
kubectl apply -f /tmp/vaultmesh-deploy/scheduler-deployment.yaml -n $NAMESPACE

# Create Service for Scheduler
cat > /tmp/vaultmesh-deploy/scheduler-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: scheduler
  namespace: $NAMESPACE
  labels:
    app: scheduler
spec:
  type: LoadBalancer
  selector:
    app: scheduler
  ports:
    - port: 9091
      targetPort: 9091
      protocol: TCP
      name: http
EOF
kubectl apply -f /tmp/vaultmesh-deploy/scheduler-service.yaml

log_success "Scheduler deployed"

# Step 10: Wait for pods
log_info "Step 10: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=psi-field -n $NAMESPACE --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=scheduler -n $NAMESPACE --timeout=300s || true
log_success "Pods ready"

# Step 11: Get service IPs
log_info "Step 11: Getting service endpoints..."
echo ""
log_info "Waiting for LoadBalancer IPs (may take 2-3 minutes)..."
sleep 30

PSI_FIELD_IP=$(kubectl get svc psi-field -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
SCHEDULER_IP=$(kubectl get svc scheduler -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
PROMETHEUS_IP=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Get Grafana password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode || echo "unknown")

# Cleanup
rm -rf /tmp/vaultmesh-deploy

# Summary
echo ""
log_success "========================"
log_success "Deployment Complete! ✨"
log_success "========================"
echo ""
log_info "📊 Service Endpoints:"
echo "  Psi-Field:   http://${PSI_FIELD_IP}:8000"
echo "  Scheduler:   http://${SCHEDULER_IP}:9091"
echo "  Prometheus:  http://${PROMETHEUS_IP}:9090"
echo "  Grafana:     http://${GRAFANA_IP}"
echo ""
log_info "🔐 Grafana Credentials:"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo ""
log_info "🧪 Quick Tests:"
echo "  curl http://${PSI_FIELD_IP}:8000/health"
echo "  curl http://${SCHEDULER_IP}:9091/health"
echo "  curl http://${PSI_FIELD_IP}:8000/metrics | grep psi_field"
echo ""
log_info "📝 View pods:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
log_info "📈 Estimated monthly cost: ~\$350-450"
echo ""
log_warning "Note: If IPs show 'pending', wait 2-3 minutes and run:"
echo "  kubectl get svc -n $NAMESPACE"
echo "  kubectl get svc -n monitoring"
echo ""
log_success "🎉 VaultMesh is now running on Google Cloud!"
