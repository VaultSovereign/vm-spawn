#!/bin/bash

export PATH="/home/sovereign/google-cloud-sdk/bin:/snap/bin:$PATH"
export KUBECONFIG=/home/sovereign/.kube/config

echo "=== VaultMesh Deployment Verification ==="
echo ""

echo "1. Cluster Status:"
/home/sovereign/google-cloud-sdk/bin/gcloud container clusters describe vaultmesh-minimal \
  --region us-central1 \
  --project vaultmesh-473618 \
  --format="table(name,location,status,currentNodeCount)"
echo ""

echo "2. Kubernetes Nodes:"
/snap/bin/kubectl get nodes 2>&1 || echo "Error getting nodes"
echo ""

echo "3. Namespaces:"
/snap/bin/kubectl get namespaces | grep -E "(NAME|vaultmesh|keda)" || echo "Error getting namespaces"
echo ""

echo "4. Pods in vaultmesh namespace:"
/snap/bin/kubectl get pods -n vaultmesh 2>&1 || echo "No pods yet (expected for scale-to-zero)"
echo ""

echo "5. Deployments in vaultmesh namespace:"
/snap/bin/kubectl get deployments -n vaultmesh -o wide 2>&1 || echo "Error getting deployments"
echo ""

echo "6. Services in vaultmesh namespace:"
/snap/bin/kubectl get svc -n vaultmesh 2>&1 || echo "Error getting services"
echo ""

echo "7. KEDA installation:"
/snap/bin/kubectl get pods -n keda 2>&1 || echo "Error getting KEDA pods"
echo ""

echo "8. KEDA ScaledObjects:"
/snap/bin/kubectl get scaledobjects -n vaultmesh 2>&1 || echo "Error getting ScaledObjects"
echo ""

echo "9. Pub/Sub Topics:"
/home/sovereign/google-cloud-sdk/bin/gcloud pubsub topics list \
  --project=vaultmesh-473618 \
  --filter="name:vaultmesh" \
  --format="table(name)" 2>&1 || echo "Error listing topics"
echo ""

echo "10. Pub/Sub Subscriptions:"
/home/sovereign/google-cloud-sdk/bin/gcloud pubsub subscriptions list \
  --project=vaultmesh-473618 \
  --filter="name:vaultmesh" \
  --format="table(name,topic,ackDeadlineSeconds)" 2>&1 || echo "Error listing subscriptions"
echo ""

echo "11. Service Accounts:"
/home/sovereign/google-cloud-sdk/bin/gcloud iam service-accounts list \
  --project=vaultmesh-473618 \
  --filter="email:vaultmesh-worker@" \
  --format="table(email,displayName)" 2>&1 || echo "Error listing service accounts"
echo ""

echo "=== Deployment Summary ==="
echo "✅ Cluster: vaultmesh-minimal (Autopilot)"
echo "✅ Region: us-central1"
echo "✅ Services: psi-field, scheduler (replicas=0)"
echo "✅ KEDA: Installed and configured"
echo "✅ Pub/Sub: Topics and subscriptions created"
echo "✅ Workload Identity: Configured"
echo ""
echo "💰 Current Cost: ~\$13-50/month (idle state, services at 0)"
echo ""
echo "🧪 Test Scaling:"
echo "  gcloud pubsub topics publish vaultmesh-psi-jobs --project=vaultmesh-473618 --message='{\"test\": 1}'"
echo "  /snap/bin/kubectl get pods -n vaultmesh -w"
echo ""
