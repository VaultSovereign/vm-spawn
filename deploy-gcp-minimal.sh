#!/bin/bash
set -euo pipefail

# VaultMesh GCP Minimal On-Demand Deployment
# Scales to ZERO when idle, wakes on queue messages
# GPU nodes only created when needed
# Perfect for solo devs / low traffic scenarios
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
CLUSTER_NAME="${CLUSTER_NAME:-vaultmesh-minimal}"
NAMESPACE="${NAMESPACE:-vaultmesh}"
USE_AUTOPILOT="${USE_AUTOPILOT:-false}"

# Check if PROJECT_ID is set
if [ -z "${PROJECT_ID:-}" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID not set. Run: export PROJECT_ID=your-project-id"
        exit 1
    fi
fi

GCR_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh"

log_info "VaultMesh Minimal On-Demand Deployment"
log_info "======================================="
log_info "Project: $PROJECT_ID"
log_info "Region: $REGION"
log_info "Cluster: $CLUSTER_NAME"
log_info "Namespace: $NAMESPACE"
log_info "Mode: Scale-to-Zero (on-demand)"
echo ""

# Step 1: Verify prerequisites
log_info "Step 1: Verifying prerequisites..."
command -v gcloud >/dev/null 2>&1 || { log_error "gcloud not found."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl not found."; exit 1; }
command -v docker >/dev/null 2>&1 || { log_error "docker not found."; exit 1; }
command -v helm >/dev/null 2>&1 || { log_error "helm not found."; exit 1; }
log_success "All prerequisites installed"

# Step 2: Enable GCP APIs
log_info "Step 2: Enabling required GCP APIs..."
gcloud services enable container.googleapis.com compute.googleapis.com \
    artifactregistry.googleapis.com monitoring.googleapis.com \
    pubsub.googleapis.com --project=$PROJECT_ID 2>/dev/null || true
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

# Step 5: Create GKE cluster
log_info "Step 5: Creating minimal GKE cluster..."

if gcloud container clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    log_warning "Cluster '$CLUSTER_NAME' already exists"
else
    if [ "$USE_AUTOPILOT" = "true" ]; then
        log_info "Creating GKE Autopilot cluster (fully managed, pay-per-pod)..."
        gcloud container clusters create-auto $CLUSTER_NAME \
            --region=$REGION \
            --project=$PROJECT_ID
        log_success "Autopilot cluster created"
    else
        log_info "Creating standard GKE cluster with minimal baseline..."
        gcloud container clusters create $CLUSTER_NAME \
            --region=$REGION \
            --release-channel=regular \
            --enable-autoscaling \
            --num-nodes=1 \
            --min-nodes=1 \
            --max-nodes=5 \
            --machine-type=e2-small \
            --disk-size=20 \
            --enable-autorepair \
            --enable-autoupgrade \
            --workload-pool="${PROJECT_ID}.svc.id.goog" \
            --addons=HorizontalPodAutoscaling,HttpLoadBalancing \
            --scopes=https://www.googleapis.com/auth/cloud-platform \
            --project=$PROJECT_ID
        log_success "Minimal cluster created (1-5 e2-small nodes)"
    fi
fi

# Step 6: Get credentials
log_info "Step 6: Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID
log_success "Credentials configured"

# Step 7: Install KEDA (for scale-to-zero)
log_info "Step 7: Installing KEDA for queue-driven autoscaling..."
helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

if helm list -n keda | grep -q keda; then
    log_warning "KEDA already installed"
else
    kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
    helm install keda kedacore/keda --namespace keda --wait
    log_success "KEDA installed"
fi

# Step 8: Create namespace
log_info "Step 8: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace '$NAMESPACE' ready"

# Step 9: Create Pub/Sub topics and subscriptions
log_info "Step 9: Creating Pub/Sub topics for queue-driven scaling..."

# Create topics
gcloud pubsub topics create vaultmesh-psi-jobs --project=$PROJECT_ID 2>/dev/null || log_warning "Topic vaultmesh-psi-jobs exists"
gcloud pubsub topics create vaultmesh-scheduler-jobs --project=$PROJECT_ID 2>/dev/null || log_warning "Topic vaultmesh-scheduler-jobs exists"

# Create subscriptions
gcloud pubsub subscriptions create vaultmesh-psi-jobs-sub \
    --topic=vaultmesh-psi-jobs \
    --ack-deadline=300 \
    --project=$PROJECT_ID 2>/dev/null || log_warning "Subscription vaultmesh-psi-jobs-sub exists"

gcloud pubsub subscriptions create vaultmesh-scheduler-jobs-sub \
    --topic=vaultmesh-scheduler-jobs \
    --ack-deadline=300 \
    --project=$PROJECT_ID 2>/dev/null || log_warning "Subscription vaultmesh-scheduler-jobs-sub exists"

log_success "Pub/Sub configured"

# Step 10: Create Workload Identity binding
log_info "Step 10: Setting up Workload Identity for Pub/Sub access..."

# Create GCP service account
gcloud iam service-accounts create vaultmesh-worker \
    --display-name="VaultMesh Worker" \
    --project=$PROJECT_ID 2>/dev/null || log_warning "Service account exists"

# Grant Pub/Sub permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsub.subscriber" >/dev/null 2>&1 || true

# Create K8s service account
kubectl create serviceaccount vaultmesh-worker -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Bind K8s SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
    vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/vaultmesh-worker]" \
    --project=$PROJECT_ID >/dev/null 2>&1 || true

# Annotate K8s SA
kubectl annotate serviceaccount vaultmesh-worker \
    -n $NAMESPACE \
    iam.gke.io/gcp-service-account=vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com \
    --overwrite

log_success "Workload Identity configured"

# Step 11: Deploy services with replicas=0
log_info "Step 11: Deploying services (scaled to zero by default)..."

mkdir -p /tmp/vaultmesh-minimal

# Deploy Psi-Field (replicas=0)
cat > /tmp/vaultmesh-minimal/psi-field.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: psi-field
  namespace: $NAMESPACE
spec:
  replicas: 0  # Start at zero, KEDA will scale up
  selector:
    matchLabels:
      app: psi-field
  template:
    metadata:
      labels:
        app: psi-field
    spec:
      serviceAccountName: vaultmesh-worker
      containers:
      - name: psi-field
        image: ${GCR_REGISTRY}/psi-field:latest
        ports:
        - containerPort: 8000
        env:
        - name: PUBSUB_SUBSCRIPTION
          value: "projects/${PROJECT_ID}/subscriptions/vaultmesh-psi-jobs-sub"
        - name: GCP_PROJECT_ID
          value: "${PROJECT_ID}"
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: psi-field
  namespace: $NAMESPACE
spec:
  type: ClusterIP  # Internal only (no external IP = no LB cost)
  selector:
    app: psi-field
  ports:
  - port: 8000
    targetPort: 8000
EOF

kubectl apply -f /tmp/vaultmesh-minimal/psi-field.yaml

# Deploy Scheduler (replicas=0)
cat > /tmp/vaultmesh-minimal/scheduler.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scheduler
  namespace: $NAMESPACE
spec:
  replicas: 0  # Start at zero, KEDA will scale up
  selector:
    matchLabels:
      app: scheduler
  template:
    metadata:
      labels:
        app: scheduler
    spec:
      serviceAccountName: vaultmesh-worker
      containers:
      - name: scheduler
        image: ${GCR_REGISTRY}/scheduler:latest
        ports:
        - containerPort: 9091
        env:
        - name: PUBSUB_SUBSCRIPTION
          value: "projects/${PROJECT_ID}/subscriptions/vaultmesh-scheduler-jobs-sub"
        - name: GCP_PROJECT_ID
          value: "${PROJECT_ID}"
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: scheduler
  namespace: $NAMESPACE
spec:
  type: ClusterIP  # Internal only
  selector:
    app: scheduler
  ports:
  - port: 9091
    targetPort: 9091
EOF

kubectl apply -f /tmp/vaultmesh-minimal/scheduler.yaml

log_success "Services deployed (scaled to zero)"

# Step 12: Create KEDA ScaledObjects
log_info "Step 12: Creating KEDA ScaledObjects for queue-driven scaling..."

cat > /tmp/vaultmesh-minimal/keda-scalers.yaml <<EOF
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: psi-field-scaler
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    name: psi-field
  minReplicaCount: 0   # Scale to zero when idle
  maxReplicaCount: 10  # Scale up to 10 pods under load
  pollingInterval: 30  # Check every 30 seconds
  cooldownPeriod: 300  # Wait 5 minutes before scaling to zero
  triggers:
  - type: gcp-pubsub
    metadata:
      subscriptionName: vaultmesh-psi-jobs-sub
      subscriptionSize: "5"  # 1 pod per 5 messages
      credentialsFromEnv: GOOGLE_APPLICATION_CREDENTIALS_JSON
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: scheduler-scaler
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    name: scheduler
  minReplicaCount: 0
  maxReplicaCount: 5
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
  - type: gcp-pubsub
    metadata:
      subscriptionName: vaultmesh-scheduler-jobs-sub
      subscriptionSize: "5"
      credentialsFromEnv: GOOGLE_APPLICATION_CREDENTIALS_JSON
EOF

kubectl apply -f /tmp/vaultmesh-minimal/keda-scalers.yaml

log_success "KEDA scalers configured"

# Cleanup
rm -rf /tmp/vaultmesh-minimal

# Summary
echo ""
log_success "========================================"
log_success "Minimal Deployment Complete! 🚀"
log_success "========================================"
echo ""
log_info "💰 Cost Profile:"
echo "  • Baseline: ~\$30-50/month (1x e2-small node + control plane)"
echo "  • Idle: ~\$35/month (just control plane when scaled to zero)"
echo "  • Active: Scales up only when messages in queue"
echo "  • GPU nodes: Only created when GPU jobs submitted"
echo ""
log_info "📊 Services (scaled to zero):"
echo "  • Psi-Field: 0 pods (scales 0→10 on queue messages)"
echo "  • Scheduler: 0 pods (scales 0→5 on queue messages)"
echo ""
log_info "🔍 Monitor scaling:"
echo "  kubectl get scaledobjects -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
log_info "📨 Test scaling (publish message):"
echo "  gcloud pubsub topics publish vaultmesh-psi-jobs --message='test job'"
echo "  # Watch pods scale up:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
log_info "📈 View KEDA metrics:"
echo "  kubectl get hpa -n $NAMESPACE"
echo "  kubectl describe scaledobject psi-field-scaler -n $NAMESPACE"
echo ""
log_info "💡 Add GPU node pool (on-demand):"
echo "  gcloud container node-pools create gpu-pool \\"
echo "    --cluster=$CLUSTER_NAME --region=$REGION \\"
echo "    --machine-type=a2-highgpu-1g \\"
echo "    --accelerator type=nvidia-tesla-a100,count=1 \\"
echo "    --enable-autoscaling --min-nodes=0 --max-nodes=5 \\"
echo "    --node-taints=gpu=true:NoSchedule"
echo ""
log_success "🎉 Scale-to-zero deployment ready!"
log_info "Services will wake automatically when work arrives in Pub/Sub queues."
