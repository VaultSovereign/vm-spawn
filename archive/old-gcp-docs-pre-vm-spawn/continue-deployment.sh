#!/bin/bash
set -e

# Set PATH to include gcloud and kubectl
export PATH="/home/sovereign/google-cloud-sdk/bin:/snap/bin:$PATH"

# Configuration
PROJECT_ID="vaultmesh-473618"
REGION="us-central1"
CLUSTER_NAME="vaultmesh-minimal"
NAMESPACE="vaultmesh"

echo "🔧 Continuing VaultMesh Minimal Deployment..."
echo "=============================================="

# Step 1: Verify cluster access
echo "✓ Step 1: Verifying cluster access..."
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
kubectl get nodes

# Step 2: Create namespace
echo "✓ Step 2: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Install KEDA
echo "✓ Step 3: Installing KEDA..."
if ! helm version &>/dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add kedacore https://kedacore.github.io/charts || true
helm repo update
kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install keda kedacore/keda --namespace keda --wait --timeout=5m

# Step 4: Create Pub/Sub topics and subscriptions
echo "✓ Step 4: Creating Pub/Sub topics and subscriptions..."

# Psi-Field topic and subscription
gcloud pubsub topics create vaultmesh-psi-jobs --project=$PROJECT_ID 2>/dev/null || echo "Topic vaultmesh-psi-jobs already exists"
gcloud pubsub subscriptions create vaultmesh-psi-jobs-sub \
  --topic=vaultmesh-psi-jobs \
  --ack-deadline=600 \
  --project=$PROJECT_ID 2>/dev/null || echo "Subscription vaultmesh-psi-jobs-sub already exists"

# Scheduler topic and subscription
gcloud pubsub topics create vaultmesh-scheduler-jobs --project=$PROJECT_ID 2>/dev/null || echo "Topic vaultmesh-scheduler-jobs already exists"
gcloud pubsub subscriptions create vaultmesh-scheduler-jobs-sub \
  --topic=vaultmesh-scheduler-jobs \
  --ack-deadline=600 \
  --project=$PROJECT_ID 2>/dev/null || echo "Subscription vaultmesh-scheduler-jobs-sub already exists"

# Step 5: Set up Workload Identity
echo "✓ Step 5: Setting up Workload Identity..."

# Create GCP service account
gcloud iam service-accounts create vaultmesh-worker \
  --display-name="VaultMesh Worker Service Account" \
  --project=$PROJECT_ID 2>/dev/null || echo "Service account already exists"

# Grant Pub/Sub permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber" --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/pubsub.viewer" --condition=None

# Create Kubernetes service account
kubectl create serviceaccount vaultmesh-worker -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Bind Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/vaultmesh-worker]" \
  --project=$PROJECT_ID

# Annotate K8s service account
kubectl annotate serviceaccount vaultmesh-worker \
  -n $NAMESPACE \
  iam.gke.io/gcp-service-account=vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com \
  --overwrite

# Create secret with service account key for KEDA
echo "✓ Creating service account key for KEDA..."
gcloud iam service-accounts keys create /tmp/vaultmesh-sa-key.json \
  --iam-account=vaultmesh-worker@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID 2>/dev/null || echo "Key may already exist, using existing"

# Create K8s secret from service account key
kubectl create secret generic vaultmesh-pubsub-secret \
  -n $NAMESPACE \
  --from-literal=GOOGLE_APPLICATION_CREDENTIALS_JSON="$(cat /tmp/vaultmesh-sa-key.json)" \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f /tmp/vaultmesh-sa-key.json

# Step 6: Deploy services with replicas=0
echo "✓ Step 6: Deploying services (scale-to-zero)..."

# Psi-Field deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: psi-field
  namespace: $NAMESPACE
spec:
  replicas: 0  # Start at zero!
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
        image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/psi-field:latest
        ports:
        - containerPort: 8000
        env:
        - name: PUBSUB_SUBSCRIPTION
          value: "projects/${PROJECT_ID}/subscriptions/vaultmesh-psi-jobs-sub"
        - name: GCP_PROJECT_ID
          value: "$PROJECT_ID"
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: psi-field
  namespace: $NAMESPACE
spec:
  selector:
    app: psi-field
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP
EOF

# Scheduler deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scheduler
  namespace: $NAMESPACE
spec:
  replicas: 0  # Start at zero!
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
        image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/vaultmesh/scheduler:latest
        ports:
        - containerPort: 8080
        env:
        - name: PUBSUB_SUBSCRIPTION
          value: "projects/${PROJECT_ID}/subscriptions/vaultmesh-scheduler-jobs-sub"
        - name: GCP_PROJECT_ID
          value: "$PROJECT_ID"
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: scheduler
  namespace: $NAMESPACE
spec:
  selector:
    app: scheduler
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

# Step 7: Create KEDA ScaledObjects
echo "✓ Step 7: Creating KEDA ScaledObjects..."

# Update KEDA scalers with correct project ID
sed "s/PROJECT_ID/${PROJECT_ID}/g" k8s/keda/psi-field-scaler.yaml | kubectl apply -f -
sed "s/PROJECT_ID/${PROJECT_ID}/g" k8s/keda/scheduler-scaler.yaml | kubectl apply -f -

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📊 Cluster Status:"
kubectl get nodes
echo ""
echo "📦 Deployments (should show 0/0 replicas):"
kubectl get deployments -n $NAMESPACE
echo ""
echo "🔄 KEDA ScaledObjects:"
kubectl get scaledobjects -n $NAMESPACE
echo ""
echo "💡 Next Steps:"
echo ""
echo "1. Test scaling by publishing a message:"
echo "   gcloud pubsub topics publish vaultmesh-psi-jobs --message='{\"test\": 1}'"
echo ""
echo "2. Watch pods scale from 0 to 1:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "3. View KEDA metrics:"
echo "   kubectl describe scaledobject psi-field-scaler -n $NAMESPACE"
echo ""
echo "4. View logs:"
echo "   kubectl logs -n $NAMESPACE -l app=psi-field"
echo ""
echo "💰 Cost: ~\$13-50/month idle (services at 0 replicas)"
echo ""
